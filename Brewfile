# YMM4M compatibility-runtime build prerequisites.
#
#   brew bundle --file=Brewfile
#
# These tools build the local Wine 11.0 + source-patched DXMT runtime. They are
# NOT bundled into YMM4M.app and are not runtime components. Rosetta 2 and the
# Xcode command line tools are installed separately:
#
#   softwareupdate --install-rosetta --agree-to-license
#   xcode-select --install
#
# x86_64 LLVM 15 (a DXMT build tool only) is fetched and SHA-256 verified by the
# bootstrap from the pinned upstream release; do not install it here.

brew "meson"
brew "ninja"
brew "cmake"
brew "mingw-w64"   # x86_64-w64-mingw32-gcc cross compiler for the Wine/DXMT PE build
brew "bison"       # GNU Bison 3+ (macOS ships an older bison); keep it on PATH for the build
brew "harfbuzz"    # provides hb-subset, used to derive the prefix-local Japanese font face
