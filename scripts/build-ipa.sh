#!/usr/bin/env bash
# Archives Dinar and exports a signed IPA.
#
#   scripts/build-ipa.sh                 → App Store Connect IPA (TestFlight / App Store)
#   scripts/build-ipa.sh adhoc           → Ad Hoc IPA for registered test devices
#   BUILD_NUMBER=7 scripts/build-ipa.sh  → override the build number (must grow per upload)
#   SKIP_TESTS=1 scripts/build-ipa.sh    → skip the unit tests
#
# Needs Xcode 26 and an Apple Developer account signed in under Xcode → Settings → Accounts.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-appstore}"
case "$MODE" in
  appstore) OPTIONS="scripts/ExportOptions-AppStore.plist" ;;
  adhoc)    OPTIONS="scripts/ExportOptions-AdHoc.plist" ;;
  *) echo "Usage: $0 [appstore|adhoc]"; exit 1 ;;
esac

BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
OUT="build/ios"
ARCHIVE="$OUT/Dinar.xcarchive"
rm -rf "$OUT" && mkdir -p "$OUT"

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  SIMULATOR=$(xcrun simctl list devices available | grep -m1 -oE "iPhone [^(]+" | sed 's/ *$//')
  echo "▶ Testing on $SIMULATOR"
  xcodebuild test -project Dinar.xcodeproj -scheme Dinar \
    -destination "platform=iOS Simulator,name=$SIMULATOR" -quiet
fi

echo "▶ Archiving (build $BUILD_NUMBER)"
xcodebuild archive \
  -project Dinar.xcodeproj -scheme Dinar -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet

echo "▶ Exporting IPA ($MODE)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" -exportPath "$OUT" \
  -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates

echo
echo "✅ $(ls "$OUT"/*.ipa)"
echo "   Upload with the Transporter app, or open the archive in Xcode → Organizer."
