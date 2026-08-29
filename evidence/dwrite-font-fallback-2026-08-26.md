# DirectWrite Japanese fallback evidence: 2026-08-26

Host: Apple M3 Ultra, macOS 26.4, Xcode 26.6. Subject: user-supplied YukkuriMovieMaker v4.55.1.1 Lite. Runtime: isolated local development staging root using Wine source base `db11d0fe6a169c457e23d007e20404643d067aa8` and the development-only DXMT profile.

The staging root originated from the developer's local CrossOver installation. It is not distributable and is not part of this repository.

## Reproducer and cause

`tests/fixtures/dwrite-font-fallback-reproducer.cpp` calls the documented `IDWriteFontFallback::MapCharacters` API for `日本語`, with Arial as the base family. It checks isolated and shared factories with empty and `ja-JP` locales.

Before the patch, all four cases returned `S_OK` and a mapped length of three, but returned no mapped font. A scoped DirectWrite trace showed the Japanese range trying `Noto Sans CJK SC` and stopping before the installed `Noto Sans CJK JP` mapping.

The cause was `fallback_builder_add_locale()` using the lookup helper that deliberately falls back to the neutral locale. Once a neutral entry existed, later `zh-Hans`, `zh-Hant`, and `ko` mappings were incorrectly appended to that neutral entry. Japanese lookup therefore selected the first Chinese mapping; when that family was unavailable, `MapCharacters` returned no font.

`patches/0003-wine-dwrite-locale-fallback.patch` makes registration use exact locale matching and adds a Wine regression assertion that distinguishes neutral and explicit-locale mappings by scale.

## Post-patch result

All four standalone cases returned:

```text
hr=0x00000000 mapped=3 scale=1.000 font=yes
mapped-family=Noto Sans CJK JP
has=1,1,1 glyphs=20220,20758,37860 complete=1
```

The rebuilt `dwrite.dll` SHA-256 is `edfbcfdb45f007174624e25696c2a2ef69c5fb2b92778f4831264aa30a16e923`.

## YMM4 workflow result

- The frame-zero preview displayed `日本語テストABC123` without missing-glyph boxes.
- YMM4 FFmpeg software export produced H.264 1280x720 at 30 fps and AAC 48 kHz stereo, duration 10.000 seconds, size 1,282,433 bytes.
- Export SHA-256: `5c93cd392d99285014e8f3a8c72c01e1104d0a24637af1293521653417177901`.
- The extracted frame preserved the Japanese text. Its SHA-256 is `0c3d2399b993ea53a78d3a40243ba4da6c6c6fab126c62802bb02a9afb514100` and it is stored as `evidence/ymm4-lite-noto-export-frame-2026-08-26.png`.

This establishes the fix on the local development runtime only. Windows-reference comparison, text entry/IME composition, a redistributable clean runtime, and the release gates remain open. The separate intermittent DXMT Metal pipeline lifetime crash is not addressed by this DirectWrite patch.
