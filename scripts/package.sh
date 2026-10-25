#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=1.2.0
APP="dist/Rock Band MIDI Bridge.app"
# Build both CPU architectures, then combine them in one distributable app.
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/RockBandMIDIBridge" "$APP/Contents/MacOS/"
swift scripts/make-icon.swift .build/Bridge.iconset
iconutil -c icns .build/Bridge.iconset -o "$APP/Contents/Resources/Bridge.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Rock Band MIDI Bridge</string>
<key>CFBundleDisplayName</key><string>Rock Band MIDI Bridge</string>
<key>CFBundleExecutable</key><string>RockBandMIDIBridge</string>
<key>CFBundleIdentifier</key><string>com.exitzero.rockbandmidibridge</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleIconFile</key><string>Bridge</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
IDENTITY="${SIGN_IDENTITY:--}"
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
if [ "$IDENTITY" != "-" ]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Rock-Band-MIDI-Bridge-$VERSION-macOS-universal.zip"
(cd dist && shasum -a 256 "Rock-Band-MIDI-Bridge-$VERSION-macOS-universal.zip" > SHA256SUMS.txt)
echo "Packaged $APP"
