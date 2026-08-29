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
cat > "$runtime_manifest" <<EOF
{
  "schema": 1,
  "kind": "ymm4m-clean-wine-dxmt",
  "wineVersion": "11.0",
  "architecture": "x86_64",
  "files": {
    "bin/wine": "$(hash_file "$work_root/runtime/bin/wine")",
    "lib/wine/x86_64-unix/winemac.so": "$(hash_file "$work_root/runtime/lib/wine/x86_64-unix/winemac.so")",
    "lib/wine/x86_64-unix/winemetal.so": "$(hash_file "$work_root/runtime/lib/wine/x86_64-unix/winemetal.so")",
    "lib/wine/x86_64-windows/d3d10core.dll": "$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/d3d10core.dll")",
    "lib/wine/x86_64-windows/d3d11.dll": "$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/d3d11.dll")",
    "lib/wine/x86_64-windows/dxgi.dll": "$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/dxgi.dll")",
    "lib/wine/x86_64-windows/winemetal.dll": "$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/winemetal.dll")",
    "lib/wine/x86_64-windows/d2d1.dll": "$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/d2d1.dll")",
    "lib/wine/x86_64-windows/dwrite.dll": "$(hash_file "$work_root/runtime/lib/wine/x86_64-windows/dwrite.dll")"
  }
}
EOF

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
