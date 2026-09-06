#!/bin/sh
set -eu

: "${YMM4M_WINE:?Set YMM4M_WINE to the validated Wine executable}"
: "${YMM4M_PREFIX:?Set YMM4M_PREFIX to the dedicated prefix}"
: "${YMM4M_EXE:?Set YMM4M_EXE to YukkuriMovieMaker.exe}"

test -f "$YMM4M_EXE" || { echo "YMM4 executable not found" >&2; exit 2; }
test -x "$YMM4M_WINE" || { echo "validated Wine executable not found" >&2; exit 2; }
test -d "$YMM4M_PREFIX" || { echo "dedicated Wine prefix not found" >&2; exit 2; }

prefix_path=$(CDPATH= cd -- "$YMM4M_PREFIX" && pwd -P)
home_path=$(CDPATH= cd -- "${HOME:?HOME is required}" && pwd -P)
case "$prefix_path" in
    /|"$home_path") echo "unsafe Wine prefix" >&2; exit 2 ;;
esac

runtime_root=$(CDPATH= cd -- "$(dirname "$YMM4M_WINE")/.." && pwd -P)
# Quiet by default; export YMM4M_WINEDEBUG for verbose tracing during debugging.
debug_channels=${YMM4M_WINEDEBUG:--all}

exec /usr/bin/env -i \
    HOME="$HOME" \
    USER="${USER:-}" \
    LOGNAME="${LOGNAME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    LANG="${LANG:-C.UTF-8}" \
    LC_ALL="${LC_ALL:-}" \
    LC_CTYPE="${LC_CTYPE:-}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    WINEPREFIX="$prefix_path" \
    WINEDEBUG="$debug_channels" \
    WINEDLLPATH="$runtime_root/lib/wine:$runtime_root/lib/dxmt" \
    WINEDLLOVERRIDES="d3d10core,d3d11,dxgi,winemetal,d2d1,dwrite=b" \
    /usr/bin/arch -x86_64 "$YMM4M_WINE" "$YMM4M_EXE" "$@"
