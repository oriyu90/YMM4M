#!/bin/sh
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
    echo "development app must be ARM64" >&2
    exit 2
}

signature=$(codesign -d --verbose=4 "$app" 2>&1)
printf '%s\n' "$signature" | grep -q '^Signature=adhoc$' || {
    echo "development app must have an ad-hoc signature" >&2
    exit 2
}
printf '%s\n' "$signature" | grep -q '^TeamIdentifier=not set$' || {
    echo "refusing an identity-signed app in the development-only DMG" >&2
    exit 2
}

staging_root=$(mktemp -d "${TMPDIR:-/private/tmp}/ymm4m-development-dmg.XXXXXX")
trap 'rm -rf -- "$staging_root"' EXIT HUP INT TERM

cp -R "$app" "$staging_root/YMM4M.app"
ln -s /Applications "$staging_root/Applications"
install -m 0644 "$repository_root/release-drafts/DEVELOPMENT_DMG_NOTICE.txt" \
    "$staging_root/READ-ME-FIRST.txt"
install -m 0644 "$repository_root/LICENSE" "$staging_root/LICENSE.txt"
install -m 0644 "$repository_root/docs/MAC_SETUP.md" \
    "$staging_root/MACでYMM4を開く手順.md"

mkdir -p "$(dirname -- "$destination")"
hdiutil create \
    -srcfolder "$staging_root" \
    -volname 'YMM4M 0.1.0 pre-alpha 3' \
    -format UDZO \
    -nospotlight \
    -noanyowners \
    "$destination" >/dev/null
hdiutil verify "$destination" >/dev/null
echo "$destination"
