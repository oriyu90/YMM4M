#!/bin/sh
set -eu

: "${YMM4M_WINE:?Set YMM4M_WINE to the validated Wine executable}"
: "${YMM4M_PREFIX:?Set YMM4M_PREFIX to the dedicated prefix}"

# Font setup invokes Wine and host font tools. Keep the same minimal boundary
# used by the product launcher while preserving only explicit font inputs.
if test "${YMM4M_ENV_SANITIZED:-}" != 1; then
  exec /usr/bin/env -i \
    HOME="${HOME:?HOME is required}" \
    USER="${USER:-}" \
    LOGNAME="${LOGNAME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    LANG="${LANG:-C.UTF-8}" \
    LC_ALL="${LC_ALL:-}" \
    LC_CTYPE="${LC_CTYPE:-}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    WINEDEBUG="-all" \
    WINEDLLOVERRIDES="winedbg.exe=d" \
    YMM4M_WINE="$YMM4M_WINE" \
    YMM4M_PREFIX="$YMM4M_PREFIX" \
    YMM4M_NOTO_FONT="${YMM4M_NOTO_FONT:-}" \
    YMM4M_HB_SUBSET="${YMM4M_HB_SUBSET:-}" \
    YMM4M_NOTO_FACE_INDEX="${YMM4M_NOTO_FACE_INDEX:-}" \
    YMM4M_ENV_SANITIZED=1 \
    "$0" "$@"
fi

export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winedbg.exe=d}"

wine_bin=$(dirname "$YMM4M_WINE")
test -x "$wine_bin/wineserver" || { echo "wineserver is missing" >&2; exit 2; }
shutdown_font_setup_processes() {
  WINEPREFIX="$YMM4M_PREFIX" "$wine_bin/wineserver" -k >/dev/null 2>&1 || true
  WINEPREFIX="$YMM4M_PREFIX" "$wine_bin/wineserver" -w >/dev/null 2>&1 || true
}
trap shutdown_font_setup_processes EXIT

fonts_dir="$YMM4M_PREFIX/drive_c/windows/Fonts"
font_dest="$fonts_dir/NotoSansCJKjp-Regular.otf"
noto_font="${YMM4M_NOTO_FONT:-}"

if test -f "$font_dest"; then
  :
else
  if test -z "$noto_font" && test -f /Users/Shared/YMM4M-NotoSansCJKjp-Regular.otf; then
    noto_font=/Users/Shared/YMM4M-NotoSansCJKjp-Regular.otf
  elif test -z "$noto_font" && test -f /Users/Shared/YMM4M-NotoSansCJK.ttc; then
    noto_font=/Users/Shared/YMM4M-NotoSansCJK.ttc
  fi

  if ! test -f "$noto_font"; then
    echo "Set YMM4M_NOTO_FONT to Noto Sans CJK JP Regular OTF or its TTC collection (SIL Open Font License)." >&2
    exit 2
  fi

  case "$noto_font" in
    *.ttc|*.TTC)
      hb_subset="${YMM4M_HB_SUBSET:-$(command -v hb-subset || true)}"
      if test -z "$hb_subset" && test -x /opt/homebrew/bin/hb-subset; then
        hb_subset=/opt/homebrew/bin/hb-subset
      elif test -z "$hb_subset" && test -x /usr/local/bin/hb-subset; then
        hb_subset=/usr/local/bin/hb-subset
      fi
      face_index="${YMM4M_NOTO_FACE_INDEX:-}"
      if test -z "$hb_subset"; then
        echo "hb-subset is required to extract the Wine-compatible Japanese face from the TTC." >&2
        exit 2
      fi
      if test -z "$face_index" && command -v fc-scan >/dev/null 2>&1; then
        face_index=$(fc-scan --format '%{index}\t%{family}\t%{style}\n' "$noto_font" |
          awk -F '\t' '$2 ~ /(^|,)Noto Sans CJK JP(,|$)/ && $3 == "Regular" { print $1; exit }')
      fi
      if test -z "$face_index"; then
        echo "Could not identify the Noto Sans CJK JP Regular face; set YMM4M_NOTO_FACE_INDEX." >&2
        exit 2
      fi
      "$hb_subset" "$noto_font" --face-index="$face_index" --unicodes='*' \
        --name-IDs='*' --passthrough-tables --output-file="$font_dest"
      ;;
    *)
      cp "$noto_font" "$font_dest"
      ;;
  esac
  chmod 0644 "$font_dest"
fi

# Remove the earlier experimental system-font links if present. They are not
# distributable and some TTC variants crash Wine's font stack.
find "$YMM4M_PREFIX/drive_c/windows/Fonts" -maxdepth 1 -type l -name 'YMM4M-HiraginoSans-*.ttc' -delete
find "$YMM4M_PREFIX/drive_c/windows/Fonts" -maxdepth 1 -type l -name 'NotoSansCJK.ttc' -delete

export WINEPREFIX="$YMM4M_PREFIX"
replacements='Segoe UI
Segoe UI Symbol
Ebrima
Microsoft Sans Serif
Lucida Sans Unicode
Yu Gothic UI
Yu Gothic
Meiryo UI
Meiryo
MS UI Gothic
MS Gothic
Microsoft YaHei UI
Microsoft JhengHei UI
SimSun
MingLiU
Malgun Gothic
Gulim'

printf '%s\n' "$replacements" | while IFS= read -r family; do
  "$YMM4M_WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' \
    /v "$family" /t REG_SZ /d 'Noto Sans CJK JP' /f >/dev/null
done

"$YMM4M_WINE" reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
  /v 'Noto Sans CJK JP Regular (OpenType)' /t REG_SZ /d 'NotoSansCJKjp-Regular.otf' /f >/dev/null

"$YMM4M_WINE" wineboot --update >/dev/null
shutdown_font_setup_processes
test -s "$font_dest" || { echo "Japanese fallback font was not installed" >&2; exit 2; }
trap - EXIT
echo "Configured Noto Sans CJK JP as a Wine-only fallback."
