#!/bin/zsh
set -e

cd "$(dirname "$0")/.."

echo "==> Building .app..."
./scripts/build-app.sh

echo "==> Installing to /Applications..."
cp -R .build/release/BearTodoMenuBar.app /Applications/

echo "==> Registering URL scheme..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/BearTodoMenuBar.app

echo "==> Killing old process..."
killall BearTodoMenuBar 2>/dev/null || true
sleep 1

echo "==> Launching app..."
open /Applications/BearTodoMenuBar.app

echo "✅ Done. The app is running."
