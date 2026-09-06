#!/bin/sh
set -eu

: "${YMM4M_WINE_RESOURCES:?Set YMM4M_WINE_RESOURCES to Wine.app Contents/Resources/wine}"
: "${YMM4M_WINE_BUILD:?Set YMM4M_WINE_BUILD to the patched Wine build directory}"
: "${YMM4M_DXMT_BUILD:?Set YMM4M_DXMT_BUILD to the patched DXMT build directory}"
: "${YMM4M_RUNTIME_STAGE:?Set YMM4M_RUNTIME_STAGE to a new destination path}"

wine_resources=$YMM4M_WINE_RESOURCES
wine_build=$YMM4M_WINE_BUILD
dxmt_build=$YMM4M_DXMT_BUILD
stage_root=$YMM4M_RUNTIME_STAGE
# Optional provenance inputs. When both are provided a schema-2 manifest is
# written (pinned source/patch attestation + a pending fixture gate that the
# bootstrap finalizes). Without them the script falls back to a schema-1
# manifest, which is still accepted by the two audited whole-file hash variants.
bootstrap_lock=${YMM4M_BOOTSTRAP_LOCK:-}
patch_dir=${YMM4M_PATCH_DIR:-}
mingw_toolchain=${YMM4M_MINGW_VERSION:-$(x86_64-w64-mingw32-gcc -dumpfullversion 2>/dev/null || echo unknown)}
llvm_toolchain=${YMM4M_LLVM_VERSION:-15.0.7}

for input_path in "$wine_resources" "$wine_build" "$dxmt_build"; do
  case "$input_path" in
    *CrossOver*|*crossover*)
      echo "CrossOver-derived inputs are forbidden for the clean runtime stage: $input_path" >&2
      exit 2
      ;;
  esac
done

if test -e "$stage_root"; then
  echo "Refusing to overwrite an existing runtime stage: $stage_root" >&2
  exit 2
fi

required_files="
$wine_resources/bin/wine
$wine_resources/lib/wine/x86_64-unix/winemac.so
$wine_build/dlls/d2d1/x86_64-windows/d2d1.dll
$wine_build/dlls/dwrite/x86_64-windows/dwrite.dll
$wine_build/dlls/winemac.drv/winemac.so
$dxmt_build/src/d3d10/d3d10core.dll
$dxmt_build/src/d3d11/d3d11.dll
$dxmt_build/src/dxgi/dxgi.dll
$dxmt_build/src/winemetal/winemetal.dll
$dxmt_build/src/winemetal/unix/winemetal.so"

printf '%s\n' "$required_files" | while IFS= read -r required_file; do
  test -z "$required_file" && continue
  if ! test -f "$required_file"; then
    echo "Missing runtime input: $required_file" >&2
    exit 2
  fi
done

if ! "$wine_resources/bin/wine" --version | grep -qx 'wine-11.0'; then
  echo "The clean candidate currently requires the verified Wine 11.0 resource base." >&2
  exit 2
fi

work_root=$(/usr/bin/mktemp -d /tmp/ymm4m-clean-runtime.XXXXXX)
case "$work_root" in
  /tmp/ymm4m-clean-runtime.*) ;;
  *) echo "Unexpected temporary directory: $work_root" >&2; exit 2 ;;
esac
cleanup_stage_work() {
  rm -rf "$work_root"
}
trap cleanup_stage_work EXIT HUP INT TERM

/usr/bin/ditto "$wine_resources" "$work_root/runtime"
mkdir -p "$work_root/runtime/lib/dxmt/x86_64-unix" \
  "$work_root/runtime/lib/dxmt/x86_64-windows"

for pe_name in d3d10core d3d11 dxgi winemetal; do
  case "$pe_name" in
    d3d10core) pe_source="$dxmt_build/src/d3d10/d3d10core.dll" ;;
    d3d11) pe_source="$dxmt_build/src/d3d11/d3d11.dll" ;;
    dxgi) pe_source="$dxmt_build/src/dxgi/dxgi.dll" ;;
    winemetal) pe_source="$dxmt_build/src/winemetal/winemetal.dll" ;;
  esac
  cp "$pe_source" "$work_root/runtime/lib/wine/x86_64-windows/$pe_name.dll"
  cp "$pe_source" "$work_root/runtime/lib/dxmt/x86_64-windows/$pe_name.dll"
done

cp "$dxmt_build/src/winemetal/unix/winemetal.so" \
  "$work_root/runtime/lib/wine/x86_64-unix/winemetal.so"
cp "$dxmt_build/src/winemetal/unix/winemetal.so" \
  "$work_root/runtime/lib/dxmt/x86_64-unix/winemetal.so"
cp "$wine_build/dlls/winemac.drv/winemac.so" \
  "$work_root/runtime/lib/wine/x86_64-unix/winemac.so"
cp "$wine_build/dlls/d2d1/x86_64-windows/d2d1.dll" \
  "$work_root/runtime/lib/wine/x86_64-windows/d2d1.dll"
cp "$wine_build/dlls/dwrite/x86_64-windows/dwrite.dll" \
  "$work_root/runtime/lib/wine/x86_64-windows/dwrite.dll"

runtime_manifest="$work_root/runtime/ymm4m-runtime.json"
hash_file() {
  shasum -a 256 "$1" | awk '{ print $1 }'
}
lock_value() {
  test -n "$bootstrap_lock" || { echo ""; return; }
  /usr/bin/plutil -extract "$1" raw -o - "$bootstrap_lock" 2>/dev/null || echo ""
}

h_wine=$(hash_file "$work_root/runtime/bin/wine")
h_winemac=$(hash_file "$work_root/runtime/lib/wine/x86_64-unix/winemac.so")
h_winemetal_so=$(hash_file "$work_root/runtime/lib/wine/x86_64-unix/winemetal.so")
h_d3d10core=$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/d3d10core.dll")
h_d3d11=$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/d3d11.dll")
h_dxgi=$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/dxgi.dll")
h_winemetal_dll=$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/winemetal.dll")
h_d2d1=$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/d2d1.dll")
h_dwrite=$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/dwrite.dll")

files_block=$(cat <<EOF
    "bin/wine": "$h_wine",
    "lib/wine/x86_64-unix/winemac.so": "$h_winemac",
    "lib/wine/x86_64-unix/winemetal.so": "$h_winemetal_so",
    "lib/wine/x86_64-windows/d3d10core.dll": "$h_d3d10core",
    "lib/wine/x86_64-windows/d3d11.dll": "$h_d3d11",
    "lib/wine/x86_64-windows/dxgi.dll": "$h_dxgi",
    "lib/wine/x86_64-windows/winemetal.dll": "$h_winemetal_dll",
    "lib/wine/x86_64-windows/d2d1.dll": "$h_d2d1",
    "lib/wine/x86_64-windows/dwrite.dll": "$h_dwrite"
EOF
)

if test -n "$bootstrap_lock" && test -n "$patch_dir" && test -f "$patch_dir/0001-dxmt-yymm4-compat.patch"; then
  cat > "$runtime_manifest" <<EOF
{
  "schema": 2,
  "kind": "ymm4m-clean-wine-dxmt",
  "wineVersion": "11.0",
  "architecture": "x86_64",
  "files": {
$files_block
  },
  "provenance": {
    "sources": {
      "wineSource": "$(lock_value sources.wineSource.sha256)",
      "wineMacBase": "$(lock_value sources.wineMacBase.sha256)",
      "freetypeSource": "$(lock_value sources.freetypeSource.sha256)",
      "dxmt": "$(lock_value sources.dxmt.sha256)",
      "nvapi": "$(lock_value sources.nvapi.sha256)",
      "directxHeaders": "$(lock_value sources.directxHeaders.sha256)"
    },
    "patches": {
      "0001-dxmt-yymm4-compat.patch": "$(hash_file "$patch_dir/0001-dxmt-yymm4-compat.patch")",
      "0002-wine-d2d1-yymm4-compat.patch": "$(hash_file "$patch_dir/0002-wine-d2d1-yymm4-compat.patch")",
      "0003-wine-dwrite-locale-fallback.patch": "$(hash_file "$patch_dir/0003-wine-dwrite-locale-fallback.patch")",
      "0004-wine-macdrv-metal-view-bridge.patch": "$(hash_file "$patch_dir/0004-wine-macdrv-metal-view-bridge.patch")"
    },
    "toolchain": { "mingw": "$mingw_toolchain", "llvm": "$llvm_toolchain" },
    "gate": {
      "producedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "runtimeFiles": {
$files_block
      },
      "winemacLoadableSha256": "pending",
      "fixtures": {},
      "results": { "fixtures": "pending", "compute100": "pending" }
    }
  }
}
EOF
else
  cat > "$runtime_manifest" <<EOF
{
  "schema": 1,
  "kind": "ymm4m-clean-wine-dxmt",
  "wineVersion": "11.0",
  "architecture": "x86_64",
  "files": {
$files_block
  }
}
EOF
fi
/usr/bin/python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$runtime_manifest"

stage_parent=$(dirname "$stage_root")
mkdir -p "$stage_parent"
mv "$work_root/runtime" "$stage_root"

echo "Staged clean Wine/DXMT candidate: $stage_root"
echo "Manifest: $stage_root/ymm4m-runtime.json"
shasum -a 256 \
  "$stage_root/lib/wine/x86_64-unix/winemac.so" \
  "$stage_root/lib/wine/x86_64-unix/winemetal.so" \
  "$stage_root/lib/wine/x86_64-windows/d3d11.dll" \
  "$stage_root/lib/wine/x86_64-windows/dxgi.dll" \
  "$stage_root/lib/wine/x86_64-windows/d2d1.dll" \
  "$stage_root/lib/wine/x86_64-windows/dwrite.dll"
