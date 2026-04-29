#!/bin/zsh
set -e

APP_NAME="BearTodoMenuBar"
BUILD_DIR=".build/release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
CERT_NAME="BearTodo Developer"

# --- Ensure consistent code signing identity ---
# Ad-hoc signing (--sign -) changes per build, which resets macOS TCC permissions.
# A persistent self-signed certificate ensures the same identity across rebuilds,
# so granted permissions (Reminders, etc.) survive reinstall.
ensure_certificate() {
    if security find-certificate -c "$CERT_NAME" 2>/dev/null | grep -q "\"$CERT_NAME\""; then
        echo "  ✅ Code signing certificate '$CERT_NAME' found"
        return 0
    fi

    echo "  🔧 Creating self-signed code signing certificate '$CERT_NAME'..."

    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    # Generate RSA key
    openssl genrsa -out "$TMPDIR/key.pem" 2048 2>/dev/null

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
        -extensions v3_req 2>/dev/null

    # Package as PKCS12 and import into login keychain
    openssl pkcs12 -export \
        -inkey "$TMPDIR/key.pem" \
        -in "$TMPDIR/cert.pem" \
        -out "$TMPDIR/cert.p12" \
        -passout pass:temp \
        -legacy 2>/dev/null

    security import "$TMPDIR/cert.p12" \
        -k "$HOME/Library/Keychains/login.keychain-db" \
        -P temp \
        -A 2>/dev/null

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

echo "✅ Built ${APP_PATH}"
echo "👉 本地运行：open ${APP_PATH}"
echo "👉 或执行：./scripts/run-local.sh"
