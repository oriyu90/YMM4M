#!/bin/sh
set -eu

if [ "${YMM4M_FIXTURE_ENV_SANITIZED:-0}" != 1 ]; then
    : "${YMM4M_WINE:?set YMM4M_WINE to the validated Wine executable}"
    : "${YMM4M_PREFIX:?set YMM4M_PREFIX to the dedicated test prefix}"
    exec /usr/bin/env -i \
        HOME="${HOME:?}" \
        USER="${USER:-}" \
        LOGNAME="${LOGNAME:-}" \
        TMPDIR="${TMPDIR:-/private/tmp}" \
        LANG="${LANG:-C.UTF-8}" \
        LC_ALL="${LC_ALL:-}" \
        LC_CTYPE="${LC_CTYPE:-}" \
        PATH='/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin' \
        YMM4M_WINE="$YMM4M_WINE" \
        YMM4M_PREFIX="$YMM4M_PREFIX" \
        YMM4M_FIXTURE_ENV_SANITIZED=1 \
        /bin/sh "$0" "$@"
fi

case "$YMM4M_WINE" in
    /*/bin/wine) ;;
    *) echo "YMM4M_WINE must be an absolute path ending in /bin/wine" >&2; exit 2 ;;
esac
case "$YMM4M_PREFIX" in
    /|"$HOME") echo "refusing unsafe prefix: $YMM4M_PREFIX" >&2; exit 2 ;;
    /*) ;;
    *) echo "YMM4M_PREFIX must be absolute" >&2; exit 2 ;;
esac
[ -x "$YMM4M_WINE" ] || { echo "Wine is not executable: $YMM4M_WINE" >&2; exit 2; }
[ -d "$YMM4M_PREFIX" ] || { echo "prefix does not exist: $YMM4M_PREFIX" >&2; exit 2; }

command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1 || {
    echo "x86_64-w64-mingw32-g++ is required" >&2
    exit 2
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname -- "$script_dir")
runtime_dir=$(dirname -- "$(dirname -- "$YMM4M_WINE")")
build_dir=$(mktemp -d "${TMPDIR:-/private/tmp}/ymm4m-runtime-fixtures.XXXXXX")
trap 'rm -rf -- "$build_dir"' EXIT HUP INT TERM

compile() {
    output=$1
    source=$2
    shift 2
    x86_64-w64-mingw32-g++ -std=c++17 -O2 -Wall -Wextra -Werror \
        "$repo_dir/tests/fixtures/$source" -o "$build_dir/$output.exe" \
        "$@" -static-libgcc -static-libstdc++
}

compile compute d3d11-compute-pipeline-reproducer.cpp -ld3d11 -ld3dcompiler -ldxgi
compile context d3d11-context-state-reproducer.cpp -ld3d11 -ldxgi
compile surface dxgi-surface2-reproducer.cpp -ld3d11 -ldxgi -luser32
compile device6 d2d-device6-reproducer.cpp -ld3d11 -ld2d1 -ldxgi -lole32
compile null d2d-null-effect-input-reproducer.cpp -ld3d11 -ld2d1 -ldxgi -lole32
compile transform d2d-3d-transform-reproducer.cpp -ld3d11 -ld2d1 -ldxgi -lole32
compile japanese d2d-japanese-text-reproducer.cpp -municode -ld3d11 -ld2d1 -ldwrite -ldxgi -lole32
compile fallback dwrite-font-fallback-reproducer.cpp -ldwrite -lole32

run_fixture() {
    name=$1
    shift
    echo "running $name"
    /usr/bin/env -i \
        HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" TMPDIR="$TMPDIR" \
        LANG="${LANG:-C.UTF-8}" PATH='/usr/bin:/bin:/usr/sbin:/sbin' \
        WINEPREFIX="$YMM4M_PREFIX" WINEDEBUG='-all' \
        WINEDLLPATH="$runtime_dir/lib/wine:$runtime_dir/lib/dxmt" \
        WINEDLLOVERRIDES='d3d10core,d3d11,dxgi,winemetal,d2d1,dwrite=b' \
        /usr/bin/arch -x86_64 "$YMM4M_WINE" "$build_dir/$name.exe" "$@"
}

run_fixture compute 100
run_fixture context
run_fixture surface
run_fixture device6
run_fixture null
run_fixture transform
japanese_output=$(printf '%s' "$build_dir/d2d-japanese-text.bmp" | sed 's|/|\\|g')
run_fixture japanese "Z:$japanese_output"
run_fixture fallback
echo "runtime fixture suite passed (8 fixtures; compute iterations: 100)"
