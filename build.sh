#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
APP=build/LimitBar.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/apple/Products/Release/LimitBar "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"
