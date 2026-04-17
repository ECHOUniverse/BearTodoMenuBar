#!/bin/zsh
set -e

APP_NAME="BearTodoMenuBar"
BUILD_DIR=".build/debug"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

# 1. Build binary
swift build

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

# 6. Ad-hoc sign the .app bundle
codesign --force --deep --sign - "${APP_PATH}"

echo "✅ Built ${APP_PATH}"
echo "👉 本地运行：open ${APP_PATH}"
echo "👉 或执行：./scripts/run-local.sh"
