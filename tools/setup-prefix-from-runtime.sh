#!/bin/sh
set -eu

: "${YMM4M_WINE:?Set YMM4M_WINE to the validated Wine executable}"
: "${YMM4M_PREFIX:?Set YMM4M_PREFIX to the dedicated prefix path}"
: "${YMM4M_BOOTSTRAP_LOCK:?Set YMM4M_BOOTSTRAP_LOCK to bootstrap.lock.json}"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache_root=${YMM4M_DOWNLOAD_CACHE:-"${HOME:?}/Library/Application Support/YMM4M/Downloads"}
font_file="$cache_root/NotoSansCJK-Regular.ttc"
font_url=$(/usr/bin/plutil -extract sources.notoSansCJKJP.url raw -o - "$YMM4M_BOOTSTRAP_LOCK")
font_hash=$(/usr/bin/plutil -extract sources.notoSansCJKJP.sha256 raw -o - "$YMM4M_BOOTSTRAP_LOCK")

mkdir -p "$cache_root"
if ! test -f "$font_file" || ! test "$(shasum -a 256 "$font_file" | awk '{print $1}')" = "$font_hash"; then
  rm -f "$font_file.part"
  /usr/bin/curl --fail --location --proto '=https' --tlsv1.2 --retry 3 \
    --output "$font_file.part" "$font_url"
  actual=$(shasum -a 256 "$font_file.part" | awk '{print $1}')
  test "$actual" = "$font_hash" || {
    rm -f "$font_file.part"
    echo "SHA-256 mismatch for NotoSansCJK-Regular.ttc" >&2
    exit 2
  }
  mv "$font_file.part" "$font_file"
fi

YMM4M_WINE="$YMM4M_WINE" YMM4M_PREFIX="$YMM4M_PREFIX" \
  "$script_dir/create-prefix.sh"
YMM4M_WINE="$YMM4M_WINE" YMM4M_PREFIX="$YMM4M_PREFIX" \
YMM4M_NOTO_FONT="$font_file" \
YMM4M_HB_SUBSET="${YMM4M_HB_SUBSET:-$(command -v hb-subset 2>/dev/null || true)}" \
YMM4M_NOTO_FACE_INDEX=0 \
  "$script_dir/configure-japanese-fonts.sh"
