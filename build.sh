#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
APP=build/AIStatusBar.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/apple/Products/Release/AIStatusBar "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
cp icon/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"
