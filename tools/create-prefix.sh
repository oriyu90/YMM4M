#!/bin/sh
set -eu

: "${YMM4M_WINE:?Set YMM4M_WINE to the validated Wine executable}"
: "${YMM4M_PREFIX:?Set YMM4M_PREFIX to a dedicated, explicit prefix path}"

# Prefix initialization launches Wine processes too. Re-exec from a minimal
# environment so host credentials, agent sockets, and loader injection settings
# cannot reach wineboot or reg.exe.
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
    YMM4M_ENV_SANITIZED=1 \
    "$0" "$@"
fi

# A clean Wine 11 prefix can hit optional device-initialization faults while
# wineboot is still building the registry. The interactive debugger otherwise
# waits forever behind the YMM4M setup UI. Disable only that debugger process;
# wineboot's exit status and the registry/profile checks below remain mandatory.
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winedbg.exe=d}"

case "$YMM4M_PREFIX" in
  /|"$HOME"|"") echo "Refusing unsafe prefix path" >&2; exit 2 ;;
esac

wine_bin=$(dirname "$YMM4M_WINE")
test -x "$wine_bin/wineserver" || {
  echo "wineserver is missing next to the validated Wine executable" >&2
  exit 2
}
shutdown_prefix_processes() {
  WINEPREFIX="$YMM4M_PREFIX" "$wine_bin/wineserver" -k >/dev/null 2>&1 || true
  WINEPREFIX="$YMM4M_PREFIX" "$wine_bin/wineserver" -w >/dev/null 2>&1 || true
}
trap shutdown_prefix_processes EXIT

mkdir -p "$YMM4M_PREFIX"
WINEPREFIX="$YMM4M_PREFIX" "$YMM4M_WINE" wineboot --init
WINEPREFIX="$YMM4M_PREFIX" "$YMM4M_WINE" reg add \
  'HKCU\Software\Microsoft\Avalon.Graphics' /v DisableHWAcceleration \
  /t REG_DWORD /d 1 /f

# wineboot may leave background services alive indefinitely. A prefix-scoped
# shutdown both flushes the registry and gives the caller a deterministic end.
shutdown_prefix_processes

registry="$YMM4M_PREFIX/user.reg"
test -f "$registry" || {
  echo "Wine did not create the prefix registry: $registry" >&2
  exit 2
}
grep -qi '^\[Software\\\\Microsoft\\\\Avalon\.Graphics\]' "$registry" || {
  echo "WPF software profile registry section was not created" >&2
  exit 2
}
grep -qi '^"DisableHWAcceleration"=dword:00000001$' "$registry" || {
  echo "WPF software profile value was not applied" >&2
  exit 2
}

cat > "$YMM4M_PREFIX/ymm4m-prefix.json" <<EOF
{
  "schema": 1,
  "purpose": "YMM4 dedicated Wine prefix",
  "wpfSoftwareProfile": true
}
EOF

trap - EXIT
