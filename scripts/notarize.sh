#!/bin/bash
# Authenticate once with: xcrun notarytool store-credentials YOUR_PROFILE ...
# This script never reads credentials into source files or publishes a release.
set -euo pipefail
cd "$(dirname "$0")/.."
PROFILE="${1:?Usage: ./scripts/notarize.sh KEYCHAIN_PROFILE}"
APP="dist/Rock Band MIDI Bridge.app"
ZIP="dist/Rock-Band-MIDI-Bridge-1.2.0-macOS-universal.zip"
codesign --verify --deep --strict "$APP"
# Confirm this is a Developer ID signed app before uploading.
if ! codesign -dvv "$APP" 2>&1 | grep -q 'Authority=Developer ID Application:'; then
    echo 'Build with SIGN_IDENTITY set to a Developer ID Application identity first.' >&2
    exit 1
fi
# Recreate the archive from the app we will staple.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait --output-format json > dist/notarization.json
if ! /usr/bin/plutil -extract status raw dist/notarization.json | grep -qx Accepted; then
    echo 'Apple has not accepted this submission. See dist/notarization.json.' >&2
    exit 1
fi
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > SHA256SUMS.txt)
echo 'Notarized app, stapled ticket and updated release ZIP are ready under dist/.'
echo 'Upload the ZIP and SHA256SUMS.txt together, then update the release notarization status.'
