#!/bin/sh
# Package a built YMM4M.app into the v1.0.0 release DMG.
#
#   tools/build-release-dmg.sh /abs/path/YMM4M.app /abs/path/YMM4M-1.0.0-arm64.dmg
#
# YMM4M has no Developer ID, so the app is ad-hoc signed and not notarized; this
# script refuses an identity-signed app so the released image matches what was
# audited. It is the release counterpart of build-development-dmg.sh and adds the
# executed license audit to the image.
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 /absolute/path/YMM4M.app /absolute/path/output.dmg" >&2
    exit 2
fi

app=$1
destination=$2
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

case "$app" in
    /*.app) ;;
    *) echo "app path must be absolute and end in .app" >&2; exit 2 ;;
esac
case "$destination" in
    /*.dmg) ;;
    *) echo "DMG destination must be absolute and end in .dmg" >&2; exit 2 ;;
esac

[ -d "$app" ] || { echo "app bundle does not exist: $app" >&2; exit 2; }
[ ! -e "$destination" ] || {
    echo "refusing to overwrite existing DMG: $destination" >&2
    exit 2
}
[ "$(lipo -archs "$app/Contents/MacOS/YMM4M")" = arm64 ] || {
    echo "release app must be ARM64" >&2
    exit 2
}

short_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - \
    "$app/Contents/Info.plist")
[ "$short_version" = "1.0.0" ] || {
    echo "expected CFBundleShortVersionString 1.0.0, got: $short_version" >&2
    exit 2
}

signature=$(codesign -d --verbose=4 "$app" 2>&1)
printf '%s\n' "$signature" | grep -q '^Signature=adhoc$' || {
    echo "release app must have an ad-hoc signature (Developer ID is unavailable)" >&2
    exit 2
}
printf '%s\n' "$signature" | grep -q '^TeamIdentifier=not set$' || {
    echo "refusing an identity-signed app in the ad-hoc release DMG" >&2
    exit 2
}
codesign --verify --deep --strict "$app"

staging_root=$(mktemp -d "${TMPDIR:-/private/tmp}/ymm4m-release-dmg.XXXXXX")
trap 'rm -rf -- "$staging_root"' EXIT HUP INT TERM

cp -R "$app" "$staging_root/YMM4M.app"
ln -s /Applications "$staging_root/Applications"
install -m 0644 "$repository_root/release-drafts/RELEASE_DMG_NOTICE.txt" \
    "$staging_root/READ-ME-FIRST.txt"
install -m 0644 "$repository_root/LICENSE" "$staging_root/LICENSE.txt"
install -m 0644 "$repository_root/LEGAL-AUDIT-v1.0.0.md" \
    "$staging_root/LEGAL-AUDIT-v1.0.0.md"
install -m 0644 "$repository_root/docs/MAC_SETUP.md" \
    "$staging_root/MACでYMM4を開く手順.md"

mkdir -p "$(dirname -- "$destination")"
hdiutil create \
    -srcfolder "$staging_root" \
    -volname 'YMM4M 1.0.0' \
    -format UDZO \
    -nospotlight \
    -noanyowners \
    "$destination" >/dev/null
hdiutil verify "$destination" >/dev/null
shasum -a 256 "$destination"
echo "$destination"
