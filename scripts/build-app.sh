#!/bin/zsh
set -e

APP_NAME="BearTodoMenuBar"
BUILD_DIR=".build/release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
CERT_NAME="BearTodo Developer"

# CI uses a temporary keychain; local uses the login keychain for persistence
if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
    CI_KEYCHAIN_PATH="$HOME/Library/Keychains/temp-build.keychain-db"
fi

# --- Ensure consistent code signing identity ---
# Ad-hoc signing (--sign -) changes per build, which resets macOS TCC permissions.
# A persistent self-signed certificate ensures the same identity across rebuilds,
# so granted permissions (Reminders, etc.) survive reinstall.
ensure_certificate() {
    # On CI, use a temporary keychain since the login keychain may be locked.
    # Locally, use the login keychain for persistence across builds.
    if [ -n "$CI_KEYCHAIN_PATH" ]; then
        if security find-certificate -c "$CERT_NAME" "$CI_KEYCHAIN_PATH" 2>/dev/null | grep -q "\"$CERT_NAME\""; then
            echo "  ✅ Code signing certificate '$CERT_NAME' found"
            return 0
        fi
    else
        if security find-certificate -c "$CERT_NAME" 2>/dev/null | grep -q "\"$CERT_NAME\""; then
            echo "  ✅ Code signing certificate '$CERT_NAME' found"
            return 0
        fi
    fi

    echo "  🔧 Creating self-signed code signing certificate '$CERT_NAME'..."

    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    # Generate RSA key
    openssl genrsa -out "$TMPDIR/key.pem" 2048 2>&1

    # Config with code signing extended key usage
    cat > "$TMPDIR/cert.cfg" << EOF
[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
x509_extensions     = v3_req
prompt              = no

[ req_distinguished_name ]
commonName          = $CERT_NAME

[ v3_req ]
basicConstraints    = critical, CA:FALSE
keyUsage            = digitalSignature
extendedKeyUsage    = codeSigning
subjectKeyIdentifier = hash
EOF

    openssl req -x509 -new \
        -key "$TMPDIR/key.pem" \
        -out "$TMPDIR/cert.pem" \
        -days 3650 \
        -config "$TMPDIR/cert.cfg" \
        -extensions v3_req 2>&1

    # Package as PKCS12 (no -legacy: macOS LibreSSL doesn't support it)
    openssl pkcs12 -export \
        -inkey "$TMPDIR/key.pem" \
        -in "$TMPDIR/cert.pem" \
        -out "$TMPDIR/cert.p12" \
        -passout pass:temp 2>&1

    if [ -n "$CI_KEYCHAIN_PATH" ]; then
        # CI: create and use a temporary keychain
        security create-keychain -p temp "$CI_KEYCHAIN_PATH" 2>&1
        security unlock-keychain -p temp "$CI_KEYCHAIN_PATH" 2>&1
        # Add to default search list so codesign finds it without --keychain flag
        security list-keychains -s "$CI_KEYCHAIN_PATH" 2>&1
        security import "$TMPDIR/cert.p12" -k "$CI_KEYCHAIN_PATH" -P temp -A 2>&1
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k temp "$CI_KEYCHAIN_PATH" 2>&1
    else
        # Local: import into login keychain (persistent across rebuilds)
        security import "$TMPDIR/cert.p12" \
            -k "$HOME/Library/Keychains/login.keychain-db" \
            -P temp \
            -A 2>&1
    fi

    echo "  ✅ Self-signed code signing certificate '$CERT_NAME' created"
}

# 1. Build binary
swift build -c release

# 2. Create .app bundle structure
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

# 3. Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"

# 4. Copy Info.plist
cp "Sources/BearTodoMenuBar/Info.plist" "${APP_PATH}/Contents/Info.plist"

# 5. Copy AppIcon
cp "resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"

# 6. Ensure persistent code signing certificate exists, then sign
echo "  📝 Setting up code signing..."
ensure_certificate
codesign --force --deep --sign "$CERT_NAME" "${APP_PATH}"

# Cleanup CI temporary keychain
if [ -n "$CI_KEYCHAIN_PATH" ]; then
    security delete-keychain "$CI_KEYCHAIN_PATH" 2>/dev/null || true
fi

echo "✅ Built ${APP_PATH}"
echo "👉 本地运行：open ${APP_PATH}"
echo "👉 或执行：./scripts/run-local.sh"
