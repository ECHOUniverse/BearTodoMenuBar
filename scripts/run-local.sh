#!/bin/zsh
set -e

cd "$(dirname "$0")/.."

echo "==> Building .app..."
./scripts/build-app.sh

echo "==> Killing old process..."
killall BearTodoMenuBar 2>/dev/null || true
sleep 1

echo "==> Launching app from build directory..."
open .build/debug/BearTodoMenuBar.app

echo "✅ Done. The app is running."
