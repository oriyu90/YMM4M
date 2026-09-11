#!/bin/sh
# Package a built YMM4M.app into a versioned release DMG.
#
#   tools/build-release-dmg.sh /abs/path/YMM4M.app /abs/path/YMM4M-1.0.1-arm64.dmg [version [notice audit]]
#
#   version  expected CFBundleShortVersionString (default: 1.0.0)
#   notice   first-run notice installed as READ-ME-FIRST.txt
#            (default: release-drafts/RELEASE_DMG_NOTICE.txt)
#   audit    executed license audit installed alongside the app
#            (default: LEGAL-AUDIT-v1.0.0.md)
#
# Relative notice/audit paths resolve under the repository root; absolute
# paths are used as-is.
#
# YMM4M has no Developer ID, so the app is ad-hoc signed and not notarized; this
# script refuses an identity-signed app so the released image matches what was
# audited. It is the release counterpart of build-development-dmg.sh.
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
    echo "usage: $0 /absolute/path/YMM4M.app /absolute/path/output.dmg [version [notice audit]]" >&2
    exit 2
fi

app=$1
destination=$2
version=${3:-1.0.0}
notice_arg=${4:-release-drafts/RELEASE_DMG_NOTICE.txt}
audit_arg=${5:-LEGAL-AUDIT-v1.0.0.md}
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$notice_arg" in
    /*) notice=$notice_arg ;;
    *) notice="$repository_root/$notice_arg" ;;
esac
case "$audit_arg" in
    /*) audit=$audit_arg ;;
    *) audit="$repository_root/$audit_arg" ;;
esac
[ -f "$notice" ] || { echo "first-run notice not found: $notice" >&2; exit 2; }
[ -f "$audit" ] || { echo "license audit not found: $audit" >&2; exit 2; }

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
[ "$short_version" = "$version" ] || {
    echo "expected CFBundleShortVersionString $version, got: $short_version" >&2
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
install -m 0644 "$notice" \
    "$staging_root/READ-ME-FIRST.txt"
install -m 0644 "$repository_root/LICENSE" "$staging_root/LICENSE.txt"
audit_name=$(basename -- "$audit")
install -m 0644 "$audit" \
    "$staging_root/$audit_name"
install -m 0644 "$repository_root/docs/MAC_SETUP.md" \
    "$staging_root/MACでYMM4を開く手順.md"

mkdir -p "$(dirname -- "$destination")"
hdiutil create \
    -srcfolder "$staging_root" \
    -volname "YMM4M $version" \
    -format UDZO \
    -nospotlight \
    -noanyowners \
    "$destination" >/dev/null
hdiutil verify "$destination" >/dev/null
shasum -a 256 "$destination"
echo "$destination"
