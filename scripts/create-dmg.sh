#!/bin/zsh
set -e

APP_NAME="BearTodoMenuBar"
BUILD_DIR=".build/release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")}"
VERSION="${VERSION#v}"
VOLUME_NAME="${APP_NAME} ${VERSION}"

if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed."
    echo "Install with: brew install create-dmg"
    exit 1
fi

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} not found. Run ./scripts/build-app.sh first."
    exit 1
fi

rm -f "${DMG_PATH}"

STAGING_DIR="$(mktemp -d)"
trap "rm -rf ${STAGING_DIR}" EXIT

cp -R "${APP_PATH}" "${STAGING_DIR}/"

echo "==> Creating DMG for ${VOLUME_NAME}..."

create-dmg \
    --volname "${VOLUME_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 400 190 \
    "${DMG_PATH}" \
    "${STAGING_DIR}"

echo "Created ${DMG_PATH}"
