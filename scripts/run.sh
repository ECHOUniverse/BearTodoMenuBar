#!/bin/zsh
set -e

usage() {
  echo "Usage: $0 [-l] [-b]"
  echo "  (none)   Build, install to /Applications, and launch"
  echo "  -l       Build and launch from build directory"
  echo "  -b       Build only, do not launch"
  exit 0
}

LOCAL=false
BUILD_ONLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    -l|--local)     LOCAL=true; shift ;;
    -b|--build-only) BUILD_ONLY=true; shift ;;
    -h|--help)      usage ;;
    *)              echo "Unknown option: $1"; usage ;;
  esac
done

cd "$(dirname "$0")/.."

echo "==> Building..."
./scripts/build-app.sh

$BUILD_ONLY && exit 0

APP="BearTodoMenuBar"

# Kill existing process with polling (max 5s)
pkill -x "$APP" 2>/dev/null || true
for i in {1..50}; do
  pgrep -x "$APP" >/dev/null 2>&1 || break
  sleep 0.1
done

if $LOCAL; then
  echo "==> Launching from build directory..."
  open ".build/release/${APP}.app"
else
  echo "==> Installing to /Applications..."
  cp -R ".build/release/${APP}.app" /Applications/
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "/Applications/${APP}.app" 2>/dev/null
  echo "==> Launching..."
  open "/Applications/${APP}.app"
fi

echo "✅ Done"
