#!/bin/zsh
set -e

APP_NAME="BearTodoMenuBar"
BUILD_DIR=".build/release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
CERT_NAME="BearTodo Developer"

cleanup_keychain() {
  [ -n "$CI_KEYCHAIN" ] && security delete-keychain "$CI_KEYCHAIN" 2>/dev/null || true
}
trap cleanup_keychain EXIT

# --- Keychain setup ---
if [ -n "${CI}${GITHUB_ACTIONS}" ]; then
  CI_KEYCHAIN="$(mktemp -d)/temp.keychain-db"
  security create-keychain -p "" "$CI_KEYCHAIN"
  security unlock-keychain -p "" "$CI_KEYCHAIN"
  security list-keychains -d user -s "$CI_KEYCHAIN"
  KEYCHAIN="$CI_KEYCHAIN"
else
  KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
fi

# --- Ensure signing certificate ---
if ! security find-certificate -c "$CERT_NAME" "$KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
  echo "  🔧 Creating code signing certificate '$CERT_NAME'..."
  TMP="$(mktemp -d)"
  openssl genrsa -out "$TMP/key.pem" 2048 2>&1
  cat > "$TMP/cert.cfg" << EOF
[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
x509_extensions     = v3_req
prompt              = no
[ req_distinguished_name ]
commonName          = ${CERT_NAME}
[ v3_req ]
basicConstraints    = critical, CA:FALSE
keyUsage            = digitalSignature
extendedKeyUsage    = codeSigning
subjectKeyIdentifier = hash
EOF
  openssl req -x509 -new -key "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -config "$TMP/cert.cfg" -extensions v3_req 2>&1
  openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/cert.p12" -passout pass:temp 2>&1
  security import "$TMP/cert.p12" -k "$KEYCHAIN" -P temp -A 2>&1
  [ -n "$CI_KEYCHAIN" ] && security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" 2>&1
  rm -rf "$TMP"
  echo "  ✅ Certificate created"
fi

# --- Build ---
swift build -c release

# --- Assemble .app ---
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")}"
VERSION="${VERSION#v}"
plutil -replace CFBundleShortVersionString -string "$VERSION" "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "${APP_PATH}/Contents/Info.plist"

cp "resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"

# --- Sign ---
codesign --force --deep --sign "$CERT_NAME" "${APP_PATH}"

echo "✅ ${APP_PATH}"
