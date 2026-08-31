#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
project_resources=${YMM4M_PROJECT_RESOURCES:-$repository_root}
if test -x "$project_resources/tools/stage-clean-wine-dxmt-runtime.sh"; then
  tool_resources="$project_resources/tools"
else
  tool_resources="$project_resources"
fi
lock_file=${YMM4M_BOOTSTRAP_LOCK:-"$repository_root/runtime/bootstrap.lock.json"}
support_root=${YMM4M_SUPPORT_ROOT:-"${HOME:?HOME is required}/Library/Application Support/YMM4M"}
cache_root=${YMM4M_DOWNLOAD_CACHE:-"$support_root/Downloads"}
# Wine passes reproducibility compiler flags through make variables that cannot
# safely represent whitespace in source/build paths. These are disposable
# caches, so keep their defaults under the whitespace-free macOS cache root.
compile_cache_root=${YMM4M_COMPILE_CACHE_ROOT:-"${HOME:?HOME is required}/Library/Caches/YMM4M"}
source_root=${YMM4M_SOURCE_ROOT:-"$compile_cache_root/Sources"}
build_root=${YMM4M_BUILD_ROOT:-"$compile_cache_root/Build"}
runtime_stage=${YMM4M_RUNTIME_STAGE:-"$support_root/Runtimes/ymm4m-wine-11.0-dxmt"}
llvm_root=${YMM4M_LLVM15_ROOT:-"$support_root/Toolchains/llvm15-x86_64"}

usage() {
  echo "usage: $0 --accept-third-party [--runtime PATH] [--prefix PATH] [--plan]" >&2
}

accept=0
plan=0
prefix=
while test $# -gt 0; do
  case "$1" in
    --accept-third-party) accept=1 ;;
    --plan) plan=1 ;;
    --runtime) shift; test $# -gt 0 || { usage; exit 2; }; runtime_stage=$1 ;;
    --prefix) shift; test $# -gt 0 || { usage; exit 2; }; prefix=$1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
  shift
done

test -f "$lock_file" || { echo "bootstrap lock not found: $lock_file" >&2; exit 2; }
test "$accept" = 1 || {
  echo "Third-party download/build requires explicit --accept-third-party consent." >&2
  exit 2
}

case "$runtime_stage" in
  /*) ;;
  *) echo "runtime destination must be an absolute path" >&2; exit 2 ;;
esac
case "$runtime_stage" in
  /|"$HOME"|*CrossOver*|*crossover*) echo "unsafe or forbidden runtime destination: $runtime_stage" >&2; exit 2 ;;
esac
if test -n "$prefix"; then
  case "$prefix" in
    /*) ;;
    *) echo "prefix must be an absolute path" >&2; exit 2 ;;
  esac
  case "$prefix" in /|"$HOME") echo "unsafe prefix: $prefix" >&2; exit 2 ;; esac
fi
case "$source_root:$build_root" in
  *" "*|*"	"*)
    echo "Wine source/build paths must not contain whitespace: $source_root / $build_root" >&2
    exit 2
    ;;
esac

json_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$lock_file"
}

if test "$plan" = 1; then
  echo "Runtime destination: $runtime_stage"
  echo "Prefix destination: ${prefix:-not requested}"
  echo "Wine source: $(json_value sources.wineSource.url)"
  echo "Wine macOS base: $(json_value sources.wineMacBase.url)"
  echo "FreeType headers: $(json_value sources.freetypeSource.url)"
  echo "DXMT source: $(json_value sources.dxmt.url)"
  echo "Japanese fallback font: $(json_value sources.notoSansCJKJP.url)"
  echo "No YMM4, Microsoft runtime/font, CrossOver, or project file will be downloaded."
  exit 0
fi

for command in curl shasum tar patch make clang meson ninja cmake x86_64-w64-mingw32-gcc; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "required build command is missing: $command" >&2
    exit 2
  }
done
mingw_version=$(x86_64-w64-mingw32-gcc -dumpfullversion)
case "$mingw_version" in
  15.2.0|16.2.0) ;;
  *)
    echo "unsupported MinGW GCC version: $mingw_version (verified: 15.2.0, 16.2.0)" >&2
    echo "Refusing to publish an unverified runtime hash variant." >&2
    exit 2
    ;;
esac
bison_bin=$(command -v bison || true)
if test -x /opt/homebrew/opt/bison/bin/bison; then
  bison_bin=/opt/homebrew/opt/bison/bin/bison
elif test -x /usr/local/opt/bison/bin/bison; then
  bison_bin=/usr/local/opt/bison/bin/bison
fi
test -n "$bison_bin" && "$bison_bin" --version | head -1 | grep -Eq ' ([3-9]|[1-9][0-9]+)\.' || {
  echo "GNU Bison 3 or newer is required to build Wine." >&2
  exit 2
}
if test -n "$prefix"; then
  hb_subset=$(command -v hb-subset || true)
  test -n "$hb_subset" || test -x /opt/homebrew/bin/hb-subset || test -x /usr/local/bin/hb-subset || {
    echo "hb-subset is required to prepare the Wine-only Japanese font." >&2
    exit 2
  }
fi
llvm_version_file="$llvm_root/lib/cmake/llvm/LLVMConfigVersion.cmake"
test -f "$llvm_version_file" && test -f "$llvm_root/lib/libLLVMCore.a" || {
  echo "LLVM 15 x86_64 toolchain is missing: $llvm_root" >&2
  echo "Install the documented LLVM 15 toolchain before building DXMT." >&2
  exit 2
}
grep -q 'PACKAGE_VERSION "15\.' "$llvm_version_file" || {
  echo "DXMT requires LLVM major version 15: $llvm_root" >&2
  exit 2
}
test ! -e "$runtime_stage" || {
  echo "refusing to overwrite existing runtime: $runtime_stage" >&2
  exit 2
}

mkdir -p "$cache_root" "$source_root" "$build_root"

download() {
  key=$1
  filename=$2
  url=$(json_value "sources.$key.url")
  expected=$(json_value "sources.$key.sha256")
  destination="$cache_root/$filename"
  if test -f "$destination" && test "$(shasum -a 256 "$destination" | awk '{print $1}')" = "$expected"; then
    echo "[cache] $filename"
    return
  fi
  rm -f "$destination.part"
  echo "[download] $url"
  /usr/bin/curl --fail --location --proto '=https' --tlsv1.2 \
    --connect-timeout 20 --speed-limit 1024 --speed-time 60 \
    --retry 3 --retry-all-errors \
    --output "$destination.part" "$url"
  actual=$(shasum -a 256 "$destination.part" | awk '{print $1}')
  test "$actual" = "$expected" || {
    rm -f "$destination.part"
    echo "SHA-256 mismatch for $filename" >&2
    exit 2
  }
  mv "$destination.part" "$destination"
}

safe_extract() {
  archive=$1
  destination=$2
  listing="$destination.list"
  tar -tf "$archive" > "$listing"
  if awk -F/ '$1 == "" {bad=1} {for(i=1;i<=NF;i++) if($i=="..") bad=1} END{exit bad?0:1}' "$listing"; then
    rm -f "$listing"
    echo "unsafe archive member in $archive" >&2
    exit 2
  fi
  rm -f "$listing"
  mkdir -p "$destination"
  tar -xf "$archive" -C "$destination"
}

download wineSource wine-wine-11.0.tar.gz
download wineMacBase wine-stable-11.0_1-osx64.tar.xz
download freetypeSource freetype-2.14.3.tar.xz
download dxmt dxmt-e55ad281.tar.gz
download nvapi nvapi-d08488f.tar.gz
download directxHeaders directx-headers-9df86f2.tar.gz
download notoSansCJKJP NotoSansCJK-Regular.ttc

wine_source=${YMM4M_WINE_SOURCE_DIR:-"$source_root/wine-11.0-ymm4m"}
freetype_source=${YMM4M_FREETYPE_SOURCE_DIR:-"$source_root/freetype-2.14.3"}
dxmt_source=${YMM4M_DXMT_SOURCE_DIR:-"$source_root/dxmt-e55ad281-ymm4m"}
wine_build=${YMM4M_WINE_BUILD_DIR:-"$build_root/wine-11.0-x86_64"}
dxmt_build=${YMM4M_DXMT_BUILD_DIR:-"$build_root/dxmt-e55ad281-x86_64"}
base_extract="$build_root/wine-base-11.0_1"

echo "[prepare] FreeType source"
if test ! -d "$freetype_source"; then
  temp=$(mktemp -d "${TMPDIR:-/tmp}/ymm4m-freetype-source.XXXXXX")
  safe_extract "$cache_root/freetype-2.14.3.tar.xz" "$temp"
  mv "$temp/$(json_value sources.freetypeSource.archiveRoot)" "$freetype_source"
  rm -rf "$temp"
fi

echo "[prepare] Wine macOS base"
if test -n "${YMM4M_WINE_BASE_RESOURCES:-}"; then
  wine_base_resources=$YMM4M_WINE_BASE_RESOURCES
elif test ! -d "$base_extract/Wine Stable.app"; then
  rm -rf "$base_extract"
  safe_extract "$cache_root/wine-stable-11.0_1-osx64.tar.xz" "$base_extract"
  wine_base_resources="$base_extract/Wine Stable.app/Contents/Resources/wine"
else
  wine_base_resources="$base_extract/Wine Stable.app/Contents/Resources/wine"
fi
test -f "$wine_base_resources/lib/libfreetype.dylib" || {
  echo "Wine macOS base does not contain the required x86_64 FreeType library." >&2
  exit 2
}
wine_base_lib_link="$build_root/wine-base-lib"
ln -sfn "$wine_base_resources/lib" "$wine_base_lib_link"

echo "[prepare] Wine source and patches"
if test ! -d "$wine_source"; then
  temp=$(mktemp -d "${TMPDIR:-/tmp}/ymm4m-wine-source.XXXXXX")
  safe_extract "$cache_root/wine-wine-11.0.tar.gz" "$temp"
  mv "$temp/$(json_value sources.wineSource.archiveRoot)" "$wine_source"
  rm -rf "$temp"
  for patch_file in \
    "$project_resources/patches/0002-wine-d2d1-yymm4-compat.patch" \
    "$project_resources/patches/0003-wine-dwrite-locale-fallback.patch" \
    "$project_resources/patches/0004-wine-macdrv-metal-view-bridge.patch"; do
    patch -d "$wine_source" -p1 < "$patch_file"
  done
fi

echo "[prepare] DXMT source and patches"
if test ! -d "$dxmt_source"; then
  temp=$(mktemp -d "${TMPDIR:-/tmp}/ymm4m-dxmt-source.XXXXXX")
  safe_extract "$cache_root/dxmt-e55ad281.tar.gz" "$temp"
  mv "$temp/$(json_value sources.dxmt.archiveRoot)" "$dxmt_source"
  rm -rf "$temp"
  patch -d "$dxmt_source" -p1 < "$project_resources/patches/0001-dxmt-yymm4-compat.patch"
fi
if test ! -f "$dxmt_source/external/nvapi/nvapi.h" || \
   test ! -f "$dxmt_source/include/native/directx/d3d11.h"; then
  temp=$(mktemp -d "${TMPDIR:-/tmp}/ymm4m-dxmt-deps.XXXXXX")
  safe_extract "$cache_root/nvapi-d08488f.tar.gz" "$temp/nvapi"
  safe_extract "$cache_root/directx-headers-9df86f2.tar.gz" "$temp/directx"
  # GitHub source archives retain the empty submodule directories. Remove
  # those placeholders before moving the pinned dependency roots; moving onto
  # an existing directory would add an unwanted archive-root nesting level.
  rm -rf "$dxmt_source/external/nvapi" "$dxmt_source/include/native/directx"
  mkdir -p "$dxmt_source/external" "$dxmt_source/include/native"
  mv "$temp/nvapi/$(json_value sources.nvapi.archiveRoot)" "$dxmt_source/external/nvapi"
  mv "$temp/directx/$(json_value sources.directxHeaders.archiveRoot)" "$dxmt_source/include/native/directx"
  rm -rf "$temp"
fi

echo "[build] Wine"
if test ! -f "$wine_build/dlls/dwrite/x86_64-windows/dwrite.dll"; then
  mkdir -p "$wine_build"
  if test ! -f "$wine_build/Makefile"; then
    # Wine embeds __FILE__ and DWARF paths in its PE modules. Map disposable
    # source/build roots to stable names so independently bootstrapped runtimes
    # have identical hashes and can retain strict whole-file verification.
    reproducible_cross_cflags="-g -O2 -ffile-prefix-map=$wine_source=/usr/src/wine-11.0 -ffile-prefix-map=$wine_build=/usr/src/wine-build"
    (cd "$wine_build" && ac_cv_lib_soname_freetype=libfreetype.dylib "$wine_source/configure" \
      --build=x86_64-apple-darwin --host=x86_64-apple-darwin --enable-archs=x86_64 \
      --disable-tests --without-alsa --without-capi --without-cups --without-dbus \
      --without-fontconfig --without-gnutls --without-gstreamer \
      --without-krb5 --without-netapi --without-oss --without-pcap --without-pcsclite \
      --without-pulse --without-sane --without-sdl --without-udev --without-unwind \
      --without-usb --without-v4l2 --without-vulkan --without-wayland --without-xcomposite \
      --without-xcursor --without-xfixes --without-xinerama --without-xinput --without-xinput2 \
      --without-xrandr --without-xrender --without-xshape --without-xshm --without-xxf86vm \
      CC='clang -arch x86_64' CXX='clang++ -arch x86_64' BISON="$bison_bin" \
      CROSSCFLAGS="$reproducible_cross_cflags" \
      FREETYPE_CFLAGS="-I$freetype_source/include" \
      FREETYPE_LIBS="-L$wine_base_lib_link -lfreetype")
  fi
  # Wine's build-time sfnt2fon helper loads the base library by its bare
  # install name. Keep the resolution inside the disposable build directory.
  ln -sfn "$wine_base_resources/lib/libfreetype.dylib" "$wine_build/libfreetype.dylib"
  make -C "$wine_build" -j"$(sysctl -n hw.logicalcpu)"
fi

echo "[build] DXMT"
if test ! -f "$dxmt_build/src/d3d11/d3d11.dll"; then
  rm -rf "$dxmt_build"
  meson setup "$dxmt_build" "$dxmt_source" \
    --cross-file "$dxmt_source/build-win64.txt" --buildtype release \
    -Dnative_llvm_path="$llvm_root" -Dwine_build_path="$wine_build"
  meson compile -C "$dxmt_build"
fi

echo "[stage] verified runtime"
YMM4M_WINE_RESOURCES="$wine_base_resources" \
YMM4M_WINE_BUILD="$wine_build" \
YMM4M_DXMT_BUILD="$dxmt_build" \
YMM4M_RUNTIME_STAGE="$runtime_stage" \
  "$tool_resources/stage-clean-wine-dxmt-runtime.sh"

if test -n "$prefix"; then
  echo "[prefix] dedicated Wine prefix and Japanese fallback font"
  YMM4M_WINE="$runtime_stage/bin/wine" YMM4M_PREFIX="$prefix" \
  YMM4M_BOOTSTRAP_LOCK="$lock_file" YMM4M_DOWNLOAD_CACHE="$cache_root" \
    "$tool_resources/setup-prefix-from-runtime.sh"
fi

echo "SETUP_RUNTIME=$runtime_stage"
test -z "$prefix" || echo "SETUP_PREFIX=$prefix"
