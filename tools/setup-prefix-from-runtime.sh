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

# A dedicated prefix plus the Japanese font needs room to spare; fail fast
# instead of failing inside wineboot. The download cache and the prefix can
# live on different volumes (custom stores), so check both filesystems.
required_free_kb=$((2 * 1024 * 1024))
free_kb_at() {
  _dir=$1
  mkdir -p "$_dir" 2>/dev/null || true
  _kb=$(df -k "$_dir" 2>/dev/null | awk 'NR==2 {print $4}')
  case "$_kb" in
    ''|*[!0-9]*) _kb=0 ;;
  esac
  printf '%s' "$_kb"
}
available_free_kb=$(free_kb_at "$cache_root")
if test "$available_free_kb" -lt "$required_free_kb"; then
  echo "Not enough free space for the Wine prefix: ${available_free_kb} KiB available at $cache_root, need about 2 GiB." >&2
  exit 2
fi
case "$YMM4M_PREFIX" in
  "$cache_root"*) prefix_free_kb=$available_free_kb ;;
  *) prefix_free_kb=$(free_kb_at "$(dirname "$YMM4M_PREFIX")") ;;
esac
if test "$prefix_free_kb" -lt "$required_free_kb"; then
  echo "Not enough free space for the Wine prefix: ${prefix_free_kb} KiB available at $YMM4M_PREFIX, need about 2 GiB." >&2
  exit 2
fi

# The Japanese fallback font needs hb-subset when the source is a TTC.
# Fail here instead of minutes into wineboot + font setup.
if ! command -v hb-subset >/dev/null 2>&1 \
    && ! test -x /opt/homebrew/bin/hb-subset \
    && ! test -x /usr/local/bin/hb-subset; then
  echo "Missing prerequisite: hb-subset (harfbuzz) is required for the Japanese fallback font." >&2
  echo "Install it, then run the setup again:" >&2
  echo "  brew install harfbuzz" >&2
  exit 2
fi

# wineboot and font subsetting run minutes without output; report liveness so
# the host UI never looks stuck. Only the phase tags the app forwards are used.
ymm4m_phase=download
ymm4m_start=$(date +%s)
ymm4m_heartbeat() {
  while true; do
    sleep 120
    echo "[$ymm4m_phase] still working ($(( $(date +%s) - ymm4m_start ))s elapsed)"
  done
}
ymm4m_heartbeat & ymm4m_heartbeat_pid=$!
ymm4m_stop_heartbeat() { kill "$ymm4m_heartbeat_pid" 2>/dev/null || true; }
trap ymm4m_stop_heartbeat EXIT HUP INT TERM
if ! test -f "$font_file" || ! test "$(shasum -a 256 "$font_file" | awk '{print $1}')" = "$font_hash"; then
  rm -f "$font_file.part"
  echo "[download] $font_url"
  /usr/bin/curl --fail --location --proto '=https' --tlsv1.2 \
    --connect-timeout 20 --speed-limit 1024 --speed-time 60 \
    --retry 3 --retry-all-errors \
    --output "$font_file.part" "$font_url"
  actual=$(shasum -a 256 "$font_file.part" | awk '{print $1}')
  test "$actual" = "$font_hash" || {
    rm -f "$font_file.part"
    echo "SHA-256 mismatch for NotoSansCJK-Regular.ttc" >&2
    exit 2
  }
  mv "$font_file.part" "$font_file"
else
  echo "[cache] NotoSansCJK-Regular.ttc"
fi

echo "[prefix] dedicated Wine prefix and Japanese fallback font"
ymm4m_phase=prefix
YMM4M_WINE="$YMM4M_WINE" YMM4M_PREFIX="$YMM4M_PREFIX" \
  "$script_dir/create-prefix.sh"
YMM4M_WINE="$YMM4M_WINE" YMM4M_PREFIX="$YMM4M_PREFIX" \
YMM4M_NOTO_FONT="$font_file" \
YMM4M_HB_SUBSET="${YMM4M_HB_SUBSET:-$(command -v hb-subset 2>/dev/null || true)}" \
YMM4M_NOTO_FACE_INDEX=0 \
  "$script_dir/configure-japanese-fonts.sh"
