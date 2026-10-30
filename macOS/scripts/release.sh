#!/bin/bash
# Builds a universal (Apple silicon and Intel) Release of Mitra for MirAIe, signed ad hoc, and
# packages it as a drag-to-Applications DMG.
#
#   scripts/release.sh [version]    # version defaults to MARKETING_VERSION in the project
#
# Output: macOS/build/release/Mitra-for-MirAIe-<version>.dmg and its SHA-256.
#
# Releases aren't signed with an Apple Developer ID, so App Groups and Keychain sharing (which
# need a provisioning profile) are unavailable. The widget extension depends on them, so it's
# removed from the release; the menu bar app and Siri/Shortcuts work fully.
#
# The app is signed with the self-signed "Mitra for MirAIe" certificate when it's in a keychain
# (the release workflow imports it from the repository's secrets). Every release signed with it
# has the same identity, so macOS keeps trusting it with the user's saved login across updates;
# an ad hoc signature changes with every build, which makes macOS ask again after each update.
# Without the certificate the script falls back to ad hoc signing. SIGN_IDENTITY overrides it.
set -euo pipefail
# Plain ASCII output: CI runs in the C locale, where bytes after a variable name can be read as part of it.
cd "$(dirname "$0")/.."

version="${1:-$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' Mitra.xcodeproj/project.pbxproj | head -1)}"
build=build/release
app_name="Mitra for MirAIe"
entitlements=Config/Mitra-Release.entitlements
identity="${SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
    if security find-certificate -c "Mitra for MirAIe" >/dev/null 2>&1; then
        identity="Mitra for MirAIe"
    else
        identity="-"
        echo "The Mitra for MirAIe signing certificate isn't in a keychain; signing ad hoc."
    fi
fi

rm -rf "$build"
mkdir -p "$build"

echo "Building ${app_name} ${version}..."
xcodebuild -project Mitra.xcodeproj -scheme Mitra -configuration Release \
    -derivedDataPath "$build/DerivedData" -destination "generic/platform=macOS" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$version" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
    CODE_SIGN_ENTITLEMENTS="$entitlements" \
    -quiet build

app="$build/DerivedData/Build/Products/Release/$app_name.app"
rm -rf "$app/Contents/PlugIns/MitraWidgets.appex"
codesign --force --sign "$identity" --options runtime --entitlements "$entitlements" "$app"
codesign --verify --deep --strict "$app"

echo "Packaging..."
staging="$build/dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
dmg="$build/Mitra-for-MirAIe-$version.dmg"
hdiutil create -volname "$app_name" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null

shasum -a 256 "$dmg" | tee "$dmg.sha256"
echo "Done: $dmg"
