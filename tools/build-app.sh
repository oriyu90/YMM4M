#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
destination=${1:-"$repository_root/.build/YMM4M.app"}

case "$destination" in
  /*) ;;
  *) destination="$PWD/$destination" ;;
esac

if [ -e "$destination" ]; then
  echo "refusing to overwrite existing app bundle: $destination" >&2
  exit 1
fi

staging_root=$(mktemp -d "${TMPDIR:-/tmp}/ymm4m-app.XXXXXX")
trap 'rm -rf "$staging_root"' EXIT HUP INT TERM
bundle="$staging_root/YMM4M.app"

cd "$repository_root"
swift build -c release --product YMM4M
binary_directory=$(swift build -c release --show-bin-path)

mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
install -m 0755 "$binary_directory/YMM4M" "$bundle/Contents/MacOS/YMM4M"
install -m 0644 app/YMM4M/Resources/Info.plist "$bundle/Contents/Info.plist"
plutil -lint "$bundle/Contents/Info.plist" >/dev/null

bootstrap_resources="$bundle/Contents/Resources/RuntimeBootstrap"
mkdir -p "$bootstrap_resources/patches" "$bootstrap_resources/tests/fixtures"
install -m 0755 tools/bootstrap-wine-dxmt-runtime.sh "$bootstrap_resources/bootstrap-wine-dxmt-runtime.sh"
install -m 0755 tools/stage-clean-wine-dxmt-runtime.sh "$bootstrap_resources/stage-clean-wine-dxmt-runtime.sh"
install -m 0755 tools/create-prefix.sh "$bootstrap_resources/create-prefix.sh"
install -m 0755 tools/configure-japanese-fonts.sh "$bootstrap_resources/configure-japanese-fonts.sh"
install -m 0755 tools/setup-prefix-from-runtime.sh "$bootstrap_resources/setup-prefix-from-runtime.sh"
install -m 0755 tools/run-runtime-fixtures.sh "$bootstrap_resources/run-runtime-fixtures.sh"
install -m 0755 tools/finalize-runtime-gate.sh "$bootstrap_resources/finalize-runtime-gate.sh"
install -m 0644 runtime/bootstrap.lock.json "$bootstrap_resources/bootstrap.lock.json"
install -m 0644 Brewfile "$bootstrap_resources/Brewfile"
mkdir -p "$bundle/Contents/Resources/YMM4"
install -m 0644 compatibility/ymm4-releases.json \
  "$bundle/Contents/Resources/YMM4/ymm4-releases.json"
for patch_file in patches/0001-dxmt-yymm4-compat.patch \
  patches/0002-wine-d2d1-yymm4-compat.patch \
  patches/0003-wine-dwrite-locale-fallback.patch \
  patches/0004-wine-macdrv-metal-view-bridge.patch; do
  install -m 0644 "$patch_file" "$bootstrap_resources/patches/$(basename "$patch_file")"
done
# The eight schema-2 acceptance-gate fixture sources.
for fixture in d3d11-compute-pipeline-reproducer.cpp d3d11-context-state-reproducer.cpp \
  dxgi-surface2-reproducer.cpp d2d-device6-reproducer.cpp \
  d2d-null-effect-input-reproducer.cpp d2d-3d-transform-reproducer.cpp \
  d2d-japanese-text-reproducer.cpp dwrite-font-fallback-reproducer.cpp; do
  install -m 0644 "tests/fixtures/$fixture" "$bootstrap_resources/tests/fixtures/$fixture"
done

# Developer ID is intentionally unavailable for development previews. Seal the
# completed bundle with an explicit ad-hoc signature so resources and embedded
# bootstrap files are covered by the same verifiable bundle signature.
codesign --force --deep --sign - "$bundle"
codesign --verify --deep --strict "$bundle"

architecture=$(lipo -archs "$bundle/Contents/MacOS/YMM4M")
if [ "$architecture" != "arm64" ]; then
  echo "unexpected host architecture: $architecture" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$destination")"
cp -R "$bundle" "$destination"
echo "$destination"
