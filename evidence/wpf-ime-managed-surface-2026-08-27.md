# WPF, managed Metal surface, and Japanese IME evidence (2026-08-27)

## Scope

This record uses the CrossOver-free Wine Stable 11.0 + source-built DXMT candidate, the dedicated test prefix, YMM4 v4.55.1.1 Lite, documented Win32 input events, and the macOS Japanese Romaji input source. YMM4 remained external and user-supplied. No YMM4 binary or proprietary implementation was inspected or modified.

## Metal-view regression and correction

The first macOS-driver bridge created a separate Wine content view directly from the HWND rectangle. The DXGI top-level/child fixture passed, but an actual YMM4 startup showed a white client area. A temporary source trace recorded YMM4 requesting a swap chain for child HWND `0x50068` while its mapped client rectangle was empty: `(3,29)-(3,29)`. The separate view therefore was not a sufficient lifecycle model for a child that is laid out after swap-chain creation.

The bridge was reduced to Wine's existing `macdrv_client_surface_create` lifecycle, which is also used by Wine's macOS OpenGL and Vulkan drivers. Wine now owns child position updates and detachment; the opaque handle owns only that managed client surface and its Metal view. The final source contains no temporary tracing.

With this version, the DXMT surface occupies YMM4's preview pane instead of covering the complete WPF client area. All eight public-API fixtures exit zero, including 100 compute iterations and top-level/child-HWND swap chains. The new `winemac.so` SHA-256 is:

```text
60978ff67066a2af56a2face8eec0bbfcf55f266067c52388b524fabd79ef037
```

## WPF software profile

Before changing compatibility code, a registry query showed that the dedicated prefix did not contain the required value:

```text
HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration
```

After applying the documented WPF software profile with `REG_DWORD 1`, the same managed-surface runtime visibly rendered YMM4's menus, item pane, preview pane, playback controls, timeline, and dialogue field. This was a missing prefix configuration, not a Wine code defect.

Tracked image: `ymm4-clean-managed-surface-wpf-2026-08-27.png`

- SHA-256: `e1e7bbf1a72c192da1686a7515dffbc7f87ff8a560fecdb2c073cc642c61e234`

## Japanese IME isolation

The YMM4 dialogue field was focused through its public UI. The ASCII control string `abc` reached the field. The active macOS input source was then verified as:

```text
com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese
```

Typing `nihongo`, requesting conversion, and confirming caused the macOS candidate UI to appear at the lower-left of the display rather than at the WPF caret. Neither one nor two confirmation keystrokes committed text to the YMM4 field. The input source was restored to `com.apple.keylayout.ABC` after every attempt.

The identical Wine 11.0 prefix and macOS input source were then tested in Wine Notepad. The same sequence committed `日本語` successfully. This demonstrates that the macdrv/macOS IME path works for a standard Win32 edit control while the tested YMM4 input path fails.

Tracked control image: `wine-notepad-japanese-ime-2026-08-27.png`

- SHA-256: `9eaedd6bcd10671b964daed4002ba8e0b38137db91fc9998c4762042b733e2df`

### Runtime-matched standalone WPF control

`tests/fixtures/wpf-ime-reproducer/` adds a standalone WPF `TextBox` using only public .NET APIs. It writes the committed `Text` value and records `PreviewTextInputStart`, `PreviewTextInputUpdate`, `PreviewTextInput`, and `TextChanged` events. It contains no YMM4 references.

YMM4 Lite's public `YukkuriMovieMaker.runtimeconfig.json` declares the self-contained `Microsoft.NETCore.App` and `Microsoft.WindowsDesktop.App` version `10.0.10`. The fixture was therefore published locally for `win-x64`, self-contained, against the same version. The resulting framework files exactly match YMM4 Lite's copies:

```text
PresentationCore.dll
b8fbf245f2868dc992c329e67f1277119dc3a3914048ec73ee88fa45acf7e0ec

PresentationFramework.dll
3a22e5bd32d90b034a5ec19657b506cac2647b46cdaef5d33e134b09585de5d2
```

Under the same clean runtime and prefix, the standalone WPF field first committed the ASCII control `abc`. After clearing the field and selecting `com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese`, the `nihongo` sequence and two confirmations committed the exact UTF-8 value `日本語`. Its event log recorded each committed character through WPF `PreviewTextInputStart`, `PreviewTextInput`, and `TextChanged`.

Tracked image: `wpf-ime-net10.0.10-japanese-pass-2026-08-27.png`

- SHA-256: `dfd0f0e32d6d0b68e12114bae2881d0ad2e4918ea19a24c244ae6a9455910ebe`
- committed UTF-8 output SHA-256: `77710aedc74ecfa33685e33a6c7df5cc83004da1bdcef7fb280f5c2b2e97e0a5`
- local event log SHA-256: `33042647fbc3e4579a7903b94f9a693307d5ba721cc15314ba02fbb077bdccbe`

This rules out a general Wine WPF `TextBox` or .NET patch-version mismatch for the tested configuration. It does not reveal how YMM4's control is implemented and does not justify a compatibility patch. No YMM4 binary was inspected or decompiled.

### Correctly focused macOS/Wine trace

A subsequent run recorded Wine's public IME debug channels and temporary diagnostics at the open-source macOS driver boundary. The test protocol explicitly reactivated the Wine window after changing the macOS input source. A discarded earlier trial had returned focus to another macOS application and is not used as failure evidence.

In the standalone WPF control, the Wine content view received the marked-text progression from `n` through `日本語`, followed by completion with `日本語`; WPF then committed the string. In YMM4, the key, main, and front Wine window received the same marked-text progression and the same completed string through the same Wine content-view path, but the visible dialogue field remained unchanged. This places the observed incompatibility above macdrv's macOS text-input boundary and Wine's IME completion path, in the tested YMM4 input-control path.

The temporary driver diagnostics were removed after capture. The clean candidate runtime and its pinned `winemac.so` were not replaced; the diagnostic runtime remains local evidence only. Because the trace does not identify a Wine defect, no additional Wine patch is justified by this result.

### Native committed-text workaround: basic gate

Because the trace does not support a Wine patch, the ARM64 host now offers a native macOS text field and transfers only explicitly committed UTF-8 text through a small, open-source Win32 helper. The helper is restricted to the tested visible `v4.55.1.1 Lite` window, reads the text from a mode-0600 temporary file rather than process arguments, clicks the already evidenced dialogue-field position, and emits documented `SendInput`/`KEYEVENTF_UNICODE` events. It does not click Add or save a project.

The end-to-end contract test launched the helper in the clean candidate runtime and dedicated prefix. It exited zero and the empty YMM4 dialogue field visibly contained the exact string `日本語`; the Add button remained untouched. YMM4 was then closed normally without opening or modifying a user project.

Tracked image: `ymm4-native-text-bridge-basic-pass-2026-08-27.png`

- SHA-256: `9f297758adcc32b739b0a43a4a984d086eafca7bd226639c57fb23fbe8d2544d`
- reproducibly linked local helper SHA-256: `c57695530db4c754bedec54e57ad59bd2056441ab4adce7027fb63248d939112`

The native host overlay was then exercised with the active macOS Japanese Romaji input source while YMM4 was closed. The focused accessibility element was verified as the overlay's `AXTextField`, and its value was read after each confirmation:

| Case | Reproducible input | Observed result |
|---|---|---|
| Hiragana / Enter | `hiragana`, Enter | `ひらがな` |
| Katakana / candidate / Space | `katakana`, Space, select, Enter | candidate UI displayed `カタカナ`; committed value began with `カタカナ` |
| Phrase conversion | `watashihagakuseidesu`, Space, Enter | candidate UI displayed the multi-part phrase and committed `わたしは学生です` |
| Kanji / cursor / Backspace | `nihonx`, Backspace, `go`, Left, Right, Space, select `日本語`, Enter | committed `日本語` |
| Shortcut suppression | the conversion keys above while the overlay was focused | runtime status stayed unchanged and no helper/YMM4 action was triggered |

Tracked host-overlay images:

- `ymm4m-native-ime-katakana-candidate-2026-08-27.png`: `886f78abb17ec47591b71fd7c0f0d855ace1d929d69c0adfb0dcadeca18ca7b7`
- `ymm4m-native-ime-phrase-candidate-2026-08-27.png`: `8d6e694cde94837ac8c606abd8c4a47b65897cf49c3816a8877f61e990ef3e6c`
- `ymm4m-native-ime-multisegment-candidate-2026-08-27.png`: `3c5537ff98a719579b3551c1fe345ae58ea7f7ed1d266859b9d7b8e5396f23f8`
- `ymm4m-native-ime-edit-candidate-2026-08-27.png`: `2ffd93ed6ca63091b896e438ae9aed27f8343b0d47333a7eeb6bb850e0cd9764`

`IME001` is therefore `pass_with_workaround`, not a direct-IME pass. Composition and editing remain in the native ARM64 host, and only an explicitly confirmed transfer invokes the version-scoped helper. Direct composition in YMM4 remains a known failure.

No user project was opened or modified during these tests.

## Local reproducible artifacts

- clean staged root: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface`
- fixture logs: `/Users/user/.ymm4m-dev/*-managed-surface.log`
- YMM4 WPF capture source: `/Users/user/.ymm4m-dev/software-profile-managed-surface.png`
- IME phase captures: `/Users/user/.ymm4m-dev/ime-stage-romaji.png`, `ime-stage-conversion.png`, `ime-stage-commit.png`
- Notepad control capture source: `/Users/user/.ymm4m-dev/ime-notepad-control.png`
- standalone WPF publish directory: `/Users/user/.ymm4m-dev/wpf-ime-reproducer-net10.0.10`
- standalone WPF output/event log: `/Users/user/.ymm4m-dev/wpf-ime-net10.0.10.txt`, `/Users/user/.ymm4m-dev/wpf-ime-net10.0.10.txt.events.log`
- standalone WPF full-desktop capture source: `/Users/user/.ymm4m-dev/wpf-ime-net10.0.10-japanese-pass.png`
- official Wine IME traces: `/Users/user/.ymm4m-dev/wpf-ime-success-trace.log`, `/Users/user/.ymm4m-dev/ymm4-ime-failure-trace.log`
- correctly focused temporary-boundary traces: `/Users/user/.ymm4m-dev/wpf-ime-cocoa-trace.log`, `/Users/user/.ymm4m-dev/ymm4-ime-cocoa-trace.log`
- correctly focused YMM4 completion capture: `/Users/user/.ymm4m-dev/ymm4-ime-cocoa-trace-commit.png`
- native text bridge final full-desktop capture source: `/Users/user/.ymm4m-dev/ymm4-native-text-bridge-final-front-2.png`

The standalone publish directory contains Microsoft .NET runtime files for local testing only. It is outside the repository and is neither a release artifact nor an input to the clean Wine/DXMT staging root.

The clean runtime remains a development candidate. Release packaging, signing, notarization, remaining Tier A gates, and the user-requested release-time license audit have not been executed.
