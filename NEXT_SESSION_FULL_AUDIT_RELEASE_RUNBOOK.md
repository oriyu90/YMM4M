# YMM4M 全面監査・修正・Release DMG作成手順書

最終更新: 2026-08-29  
用途: 次回セッションの主作業書

## 1. 目的と完了定義

次回セッションでは、システム全体を次の順で精査する。

1. メモリ安全性とconcurrency
2. GPU描画とMetal/DXMT回帰
3. アクセラレータが実際にGPUを使うことの証明
4. クラッシュ安定性、長時間負荷、異常終了復帰
5. Tier Aを中心とした動作の完全性
6. update、rollback、diagnostics、process lifecycle
7. release直前のライセンス監査
8. 署名、公証、DMG、clean-machine検証

問題が見つかったら、必ず証拠→層の分離→公開APIの最小reproducer→最小修正→全回帰の順に進める。

### release-readyの必須条件

- 未解決のmemory corruption、use-after-free、out-of-bounds、data race、leak trend、crash、hangが0件。
- GPU描画の正しさとGPU実使用が直接traceで証明済み。
- `compatibility/features.yaml` のTier Aに `partial`、`fail`、`crash`、`untested` が残っていない。
- Windows reference、可聴再生、利用可能なVoiceItem、OS/hardware matrixが完了。
- update/rollback/interrupted recovery/crash recoveryが合格。
- 全bundled componentの出所、license、notice、source義務が確定。
- Developer ID Application、Hardened Runtime、nested signing、notarytool、stapler、Gatekeeperが合格。
- 新規macOS user相当の環境でDMGから導入・起動・編集・再生・export・再起動が成功。

一つでも満たせない場合は、DMGを作れてもrelease-readyと呼ばない。

## 2. 開始時に読む文書

1. `AGENTS.md`
2. `COMMON_RULES.md`
3. `NEXT_SESSION_HANDOFF.md`
4. 本文書
5. `STATUS.md`
6. `compatibility/features.yaml`
7. `runtime.lock.json`
8. `tests/e2e-local/TEST_PLAN.md`
9. `evidence/quality-gates-2026-08-29.md`
10. 監査対象に関係するevidence

### 最終ライセンス監査書

`YMM4M ライセンス監査・実装判断指示.md` はまだ開かない。メモリ/GPU/stability/Tier A/update/recoveryがすべて合格し、実際のrelease staging内容が確定したrelease直前に限り、初めて全文を読む。その指示と本文書が衝突する場合は監査書を優先する。

## 3. 開始時に確認する外部前提

| 前提 | 使用目的 | ない場合 |
|---|---|---|
| Developer ID Application identity | release signing | release DMG作成不可 |
| notarytool用keychain profile | notarization | release gateで停止 |
| 必要なApple restricted entitlement | ARM64 Wine/FEXをreleaseする場合 | backendをunavailableのままにする |
| Windows reference環境 | frame/audio/UI比較 | Tier Aをpassにしない |
| 利用許諾済みLite対応音声engine | VoiceItem workflow | 無断導入しない |
| speakerで確認できる操作者 | audible playback | 波形だけで代替しない |
| 対応宣言するMac/macOS matrix | clean-machine test | 未検証構成をsupportと書かない |

認証情報をrepository、evidence、shell historyへ書かない。keychain profileを使う。不足する前提はセッション開始後に一度にまとめてユーザーへ依頼する。

## 4. 不変の安全ルール

- YMM4の未文書化動作を推測しない。
- proprietary YMM4を逆コンパイルしない。
- YMM4、Microsoft runtime/font、CrossOverのbinaryをGitまたはDMGに入れない。
- DXMTをMITと扱わない。
- SIP、Gatekeeperを無効化しない。
- WPF、D3D11、D3D12、WebView2、audio、filesystem、process crashを混同しない。
- compatibility code変更前に必ずevidenceとreproducerを保存する。
- user projectを上書きしない。必ず新規名のcopyで試験する。
- current prefixを初期化しない。変更試験は新規dedicated prefixで行う。
- パッチは小さく、upstreamで説明可能にする。
- 新しい失敗を過去のpassで上書きしない。
- release artifactに出所不明componentがあれば停止する。

## 5. 開始スナップショット

### 5.1 Git/source provenance

2026-08-29時点で `git ls-files` は0件、repository全体がuntrackedである。

```sh
cd '/Users/user/places/Project/YMM4移植'
git status --short
git ls-files | wc -l
```

このままではrelease sourceを特定できない。`.gitignore` とbinary除外を検査し、baseline/commitを作る権限が不明な場合はユーザーに確認する。ZIP、EXE、DLL、runtime build、DMGはstageしない。

### 5.2 環境と入力の固定

```sh
cd '/Users/user/places/Project/YMM4移植'
python3 tools/validate-runtime-lock.py
python3 tools/validate-compatibility.py
shasum -a 256 runtime.lock.json compatibility/features.yaml
sw_vers
uname -m
system_profiler SPHardwareDataType SPDisplaysDataType
xcodebuild -version
swift --version
```

serial number等はredact後、次を1つのmanifestに記録する。

- source commitまたはsource hash inventory
- YMM4 ZIP/executable hashとversion
- Wine/DXMT commit、patch、binary hash
- prefix/profile
- project/media hash
- macOS/Xcode/SDK/hardware/display scale
- operator/timezone/timestamp

このmanifestがない実行はrelease evidenceにしない。

## 6. 問題発見から修正まで

1. hash、コマンド、環境、経過時間、exit statusを保存。
2. isolated copyで再現。
3. `compatibility/features.yaml` を現在の `partial/fail/crash` へ更新。
4. native host、Wine/macdrv、DXMT/Metal、WPF/.NET、YMM4 UI、media、voice、WebView2を分離。
5. 公開APIの最小reproducerまたは成功/失敗対照を作る。
6. 修正前の失敗をevidenceに固定。
7. 原因に直接対応する最小修正を実装。
8. reproducer、近接fixture、8-fixture suite、YMM4実UIの順で回帰。
9. 30回以上の反復または必要なsoakで再発なしを確認。
10. evidence、`STATUS.md`、`COMMON_RULES.md`、`NEXT_SESSION_HANDOFF.md`、registryを同時更新。

### バグ報告必須項目

```text
ID / severity / layer
first bad current result / last known good
environment manifest
minimal reproducer
expected / actual / frequency n/N
crash or exception signature
memory/GPU/process evidence
root cause / rejected hypotheses
fix / regression tests / remaining risk
compatibility status change / artifact hashes
```

## 7. Phase A: メモリ安全性

### 7.1 通常quality gate

```sh
cd '/Users/user/places/Project/YMM4移植'
swift build
swift run YMM4MContractTests
python3 -m unittest discover tests -v
python3 tools/validate-runtime-lock.py
python3 tools/validate-compatibility.py
dotnet build bridge/YMM4MBridge/YMM4MBridge.csproj -warnaserror
sh -n tools/*.sh
git diff --check
```

Swift 6 concurrency、C/C++、C# warningはrelease候補で0件にする。YMM4 proprietary DLLが必要なbridgeはlocal integrationに分ける。

### 7.2 sanitizer/static analysis

AddressSanitizerとThreadSanitizerは別buildで行う。現行toolchainのhelpでoptionを確認する。

```sh
swift build --help | rg sanitize
swift build --sanitize=address
swift run --sanitize=address YMM4MContractTests
swift build --sanitize=thread
swift run --sanitize=thread YMM4MContractTests
```

- sanitizer有効のnative hostでFinder intake、IME overlay、runtime probe、YMM4 launch/closeを実行。
- native macOS C/C++はASan、UBSan、TSanを別々実行。
- Win32 fixtureは `-Wall -Wextra -Werror` で追加build。
- Wine/DXMT sanitizer buildは現行upstream手順を一次資料で確認し、release runtimeと別root/prefixで実行。
- translated processでsanitizerが使えない場合は理由を証拠化し、Guard Malloc、MallocStackLogging、zombie、crash log、repeat stressで補完。
- sanitizer runtimeをrelease appに含めない。

### 7.3 leak・メモリ・resource soak

`xctrace list templates`と現行Apple公式資料でLeaks/Allocations/System Traceの実行方法を確認する。記憶だけでコマンドを固定しない。

対象process:

- YMM4M host
- YukkuriMovieMaker
- wineserver/Wine helper/Win32Service
- ffmpeg/native encoder
- voice/VST3/OFX/WebView2 child（使う場合）

反復sequence:

1. cold launch。
2. Tier A 10秒projectをopen。
3. previewを10往復。
4. add/duplicate/move/split/delete/undo/redoを反復。
5. dialog open/cancel 100回。
6. export 10回。
7. close/reopen 30回。
8. 2時間以上soak。

各processのresident/private/virtual/peak memory、allocation/leak stack、GPU allocation、thread、handle/file descriptor、起動・終了を記録。

合格条件:

- sanitizer/Guard Malloc/zombie error 0。
- warm-up後に同一sequenceで無制限な単調増加なし。
- normal close後のprocess/thread/handle残留なし。
- leak候補のownership/stackが説明できる。
- OS/runtime cacheと推測せず、同一条件の対照で判定。

## 8. Phase B: GPU描画とGPU実使用

### 8.1 経路の分離

1. WPF software rendering
2. WineD3D Vulkan/OpenGL
3. source-patched DXMT D3D11→Metal
4. Wine Direct2D/DirectWrite patch
5. FFmpeg software decode/upload
6. native encoder/VideoToolbox
7. D3D12/DirectML/WebView2（Tier Aと分離）

### 8.2 低レベル回帰

```sh
cd '/Users/user/places/Project/YMM4移植'
YMM4M_WINE='/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface/bin/wine' \
YMM4M_PREFIX='/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix' \
tools/run-runtime-fixtures.sh
```

- 8 fixture、100 compute iteration、top-level/child HWND、Japanese text/fallbackが合格してから先へ進む。
- create/render/readback/destroyを1,000回以上。
- resize、minimize/restore、display scale、child view move。
- command list、effect chain、null input、image brush、transparent clear。
- Metal validation error 0。有効化方法は実行時点のApple一次資料で確認する。

### 8.3 実YMM4の描画/performance matrix

720p30、1080p30、1080p60、4K30の各条件で:

- text only
- PNG/JPEG/GIF
- H.264/AAC
- opacity/position/scale/rotation/crop
- blur/outline/shadow/chroma key/color adjustment/transition
- 3 effects / 10 effects

を試験する。average FPS、p50/p95/p99 frame time、dropped frame、CPU %、process別GPU time/%、memory/GPU memory、Metal error、frame hash、Windows pixel diff、A/V syncを保存する。

### 8.4 GPU使用の直接証明

ウィンドウ表示だけでGPU使用と判定しない。

1. `xctrace list templates` で現在のMetal System Trace/GPU関連templateを確認。
2. YMM4/Wine/DXMT実行中のcommand buffer、encoder、GPU intervalを取得。
3. 必要な `powermetrics` は権限と取得項目を事前確認し、GPU/CPU power/frequencyの最小範囲だけを取得。
4. WPF software profileとDXMT profileで同一projectを対照。
5. compute fixtureのGPU traceとCPU readback値を対応付ける。
6. FFmpeg software、DXMT、VideoToolboxをprocess/APIごとに分離。

合格条件:

- DXMT対象操作で対応するMetal GPU workをtraceで確認。
- software/accelerated pathのCPU・GPU・frame time差が実測で説明可能。
- device loss、command-buffer error、frame破損、継続stallが0。
- Windows reference差の原因が特定済み。不明な差をpassにしない。

## 9. Phase C: クラッシュ安定性

### 9.1 Win32Serviceの最優先分離

`YukkuriMovieMaker.Win32Service.exe` のMono native crash bannerは未特定crashのままである。main windowが開くことを理由にreleaseから除外しない。

- PID/parent PID/architecture/start/end/exit codeを記録。
- crash report、Wine log、YMM4公開log、WMI errorを時刻で分離。
- success/failure対照で公開機能影響を特定。
- WPF、WMI、Mono、Wine service、YMM4機能の層を混ぜない。
- 原因が不明ならrelease stop。

### 9.2 反復・soak matrix

| 試験 | 最低条件 | 合格 |
|---|---:|---|
| cold launch→normal close | 100回 | crash/hang/modal残留 0 |
| PROJECT001 fresh Wine-server reopen | 30回 | 30/30、hash不変 |
| Finder `.ymmp` open | 30回 | 30/30、M: path一致 |
| preview play/seek/stop | 1,000操作 | device loss/hang 0 |
| edit/undo/redo | 500操作 | state破損 0 |
| GIF export | 30回 | crash 0、frame正常 |
| H.264/AAC export | 30回 | crash 0、A/V sync合格 |
| dialog open/cancel | 100回 | blank/hang 0 |
| resize/minimize/sleep-resume | 各50回 | surface破損 0 |
| mixed workload | 8時間 | crash/hang/leak trend 0 |

低頻度の1回だけのcrashも失敗とする。correctness→stability→repeatability→performanceの順を守る。

### 9.3 fault injection/recovery

新規test prefix/store/project copyだけで:

- export中のnative encoder/YMM4/wineserver異常終了
- disk-full相当
- update stage中断
- current symlink切替直前/直後の異常終了
- corrupt/incomplete archive
- 競合M: mapping
- media消失、read-only、日本語/長いpath

を試験する。user projectと旧versionの保持、recovery/rollbackの明示選択、partial stagingのcleanup、redacted diagnosticsを合格条件にする。

## 10. Phase D: 動作の完全性

### 10.1 registryをTier A全体へ拡張

仕様上Tier Aだが独立featureのない通常drag-and-drop、clipboard等を `compatibility/features.yaml` に追加し、test ID、dependencies、evidenceを付ける。

### 10.2 必須項目

#### UI/FONT/IME

- main/menu/settings/popup/context menu/property/color/font/file dialog
- Retina/DPI、Japanese/CJK/symbol/emoji、bold/italic/ruby/spacing/effects
- 直接IMEとnative overlay workaroundを分ける
- candidate/multi-segment/cursor/Backspace/shortcut suppression

#### EDIT/PROJECT

- create/add/select/move/trim/split/duplicate/delete/undo/redo
- multi-layer、timeline zoom/scroll
- save/Save As/close/reopen/Finder open
- 保存前後project hash/public JSON比較
- 許諾済みLite対応voice engineのVoiceItem workflow

#### IMAGE/AUDIO/VIDEO

- PNG/JPEG/GIFと必要media format
- WAV/MP3、mono/stereo、44.1/48 kHz、volume/pan/speed/pitch
- speaker可聴再生、device変更、sleep-resume
- H.264/AAC、thumbnail/seek/split/A-V sync/save/reopen
- missing/corrupt media、resolution/fps/sample-rate edge case

#### EFFECT/PREVIEW/EXPORT

- opacity/position/scale/rotation/crop/blur/outline/shadow/chroma key/color adjustment/transition
- frame 0/30/60/150/299のWindows reference比較
- FFmpeg software exportのduration/RGB/audio timing/non-silence
- project/writer mismatchを事前errorにし、crashさせない
- native encoder/VideoToolboxはpublic ABI/frame/audio formatが確定するまでrelease有効化しない

#### Finder/DnD/Clipboard

- `.ymmp` LaunchServices
- `.ymme` は公式動作を推測しない
- Finder→timeline/file field/project
- plain text/image/YMM4 item/effect copy-paste
- Photos等virtual fileはTier Bに分離

### 10.3 Windows reference

同一YMM4 ZIP、project/media、font、writer settingで、Windows version、GPU/driver、display scale、plugin inventoryを固定する。frame PNG、lossless audio、ffprobe、frame hash、waveform/timing、UI screenshotを取得する。比較前にcolor/codec/font rasterizationの許容差を定義し、結果を見て敷居値を変えない。

### 10.4 完全性gate

- Tier A partial/fail/crash/untestedが0。
- create→edit→preview→save→reopen→exportがclean testで完遂。
- workaroundはUIにversion scope、副作用、解除条件を表示。
- unsupported機能は実行前に理由を表示。
- user projectの無断変更が0。

## 11. Phase E: update、rollback、diagnostics

`YMM4M Runtime Update` と `YMM4 Application Update` を別状態機械にする。YMM4公式updaterのWine上の動作を先にブラックボックス試験し、動く場合は尊重する。YMM4内部を勝手に書き換えない。

`tools/manage-ymm4-version.py` のprimitiveから次を完成させる。

- verified versioned install
- known compatible/unknown/known broken分類
- Continue/Use tested version
- staged download/hash verification/atomic activation
- old version保持とrollback
- interrupted update cleanup/retry
- concurrent launch/update lock
- disk capacity事前確認
- progress/error/UIの最終確認

process treeにはprocess名、PID/parent PID、architecture、start/end、exit code/signal、known/unknown roleを記録する。YMM4、ffmpeg、voice、Vst3Scanner、OfxScanner、WebView2、Win32Service、wineserver、native encoderを個別に扱う。

## 12. Phase F: release前security gate

- allow-listed environmentにcredential、agent socket、loader injectionが漏れない。
- bridgeは127.0.0.1、random token、version/length validation、bad-token/oversize rejectionが合格。
- temporary fileは0600、size limit、cleanup、symlink/path traversal拒否。
- M: mappingはsymlink-aware containment、競合非上書き、Z:は標準UIに露出しない。
- archiveはtraversal、absolute path、symlink、size bomb、hash driftを拒否。
- diagnosticsはHOME/user/auth/API key/token/pathをredact。
- bundleにsecret、debug entitlement、sanitizer、test media、YMM4 binary、temporary traceがない。
- scannerのfalse positiveを閉じる場合はdata flowと到達不可能性を証明。

## 13. Phase G: 最終ライセンス監査

このPhase前にmemory/GPU/crash/Tier A/update/recoveryがすべて合格していること。その後で初めて保留中の監査書を全文読み、次を確定する。

- component name/version/source/hash/license/notice/source-offer/distribution decision
- `licenses/`、`sources/`、`THIRD_PARTY_NOTICES.md`、`LICENSE_MATRIX.md`と実配布物の一致
- CrossOver、YMM4、許諾不明Microsoft runtime/font/voice componentの除外
- `UNKNOWN` component 0件

配布不可componentを置き換えた場合は関連する全監査をやり直す。

## 14. Phase H: 署名・公証・DMG

### 14.1 release build

- clean build rootから作る。
- development用 `tools/build-app.sh` をそのままrelease packagingにしない。
- input manifestと許可済みcomponentを固定するrelease scriptを作る。
- destinationを上書きせずversioned stagingを使う。
- app/DMGをGitにcommitしない。

### 14.2 inner-to-outer signing

Wine/runtimeを.appに含める場合は、executable/helper→dylib→framework/XPC/service→nested bundle→main appの順に署名する。`codesign --deep` だけで署名しない。

必須:

- Developer ID Application
- Hardened Runtime
- timestamp
- componentごとの必要最小entitlement

`get-task-allow`、library validation無効化、JIT/unsigned executable memoryはAppleの正式要件と必要性が証明できない限り追加しない。

```sh
codesign --verify --deep --strict --verbose=4 '/absolute/path/YMM4M.app'
codesign -d --entitlements :- '/absolute/path/YMM4M.app'
spctl --assess --type execute --verbose=4 '/absolute/path/YMM4M.app'
```

`--deep` は検証には使っても署名手順の代替にしない。

### 14.3 DMG/notarization

`hdiutil` の現行helpを確認し、YMM4M.app、Applications symlink、必要noticeだけを含む再現可能DMGを作る。YMM4を同梱しない。

notarytoolは次回セッション時点のApple公式資料とhelpでsyntaxを確認し、keychain profileを使う。

```sh
xcrun notarytool submit '/absolute/path/YMM4M.dmg' --keychain-profile '<profile>' --wait
xcrun stapler staple '/absolute/path/YMM4M.dmg'
xcrun stapler validate '/absolute/path/YMM4M.dmg'
spctl --assess --type open --context context:primary-signature --verbose=4 '/absolute/path/YMM4M.dmg'
```

submission ID/status/log、stapler resultを保存。失敗後は新しいartifact hashで再実行する。

## 15. Phase I: clean-machine相当test

新規macOS userまたは同等の環境で:

1. quarantine付きDMGをopen。
2. Gatekeeper/signing/notarizationを確認。
3. Applicationsへcopyしfirst launch。
4. user-supplied公式YMM4 ZIPの検査・導入。
5. dedicated prefix/runtime setupとprobe。
6. `.ymmp` Finder open。
7. edit/preview/save/reopen/speaker playback/export。
8. app再起動とMac再起動後の再試験。
9. update/rollback/recovery/diagnostics。
10. uninstall。user projectは削除しない。

対応宣言する各macOS/hardwareで実行。build machineの既存prefix/font/environmentに暗黙依存しない。

## 16. 最終成果物と添付

```text
YMM4M-<version>-macOS-arm64.dmg
YMM4M-<version>-release-manifest.json
YMM4M-<version>-test-report.md
YMM4M-<version>-component-inventory.json
YMM4M-<version>-notarization.json
YMM4M-<version>-checksums.txt
```

manifestにversion/build、source commit/inventory hash、app/DMG hash、external-only YMM4 tested hash、Wine/DXMT commit/patch hash、component inventory hash、certificate fingerprint、notarization ID/status、supported matrix、registry hash、evidence index、known workaroundを記録する。

最終応答では、実在するDMGの絶対pathをclickable linkで添付し、SHA-256、signing、notarization、stapler、Gatekeeper、clean-machine test結果を併記する。外部upload/publishはユーザーの明示指示がある場合のみ行う。

## 17. 最終checklist

### Source/provenance

- [ ] release commitまたはsource inventoryを特定できる
- [ ] proprietary binaryがrepositoryにない
- [ ] runtime/component/source/patch hashが一致
- [ ] credential scan 0

### Memory/concurrency

- [ ] Swift ASan/TSan合格
- [ ] native ASan/UBSan/TSanまたは証拠付き代替gate合格
- [ ] leak/soakの無制限増加なし
- [ ] process/thread/handle残留なし

### GPU/rendering

- [ ] 8 fixture + stress合格
- [ ] Metal validation error 0
- [ ] DXMTのGPU workをtraceで確認
- [ ] 720p30/1080p30/1080p60/4K30合格
- [ ] Windows reference合格

### Stability

- [ ] cold launch 100/100
- [ ] PROJECT001 30/30
- [ ] Finder open 30/30
- [ ] export各30/30
- [ ] 8時間soak合格
- [ ] Win32Serviceを含む未特定crash 0
- [ ] fault injection/recovery合格

### Functional completeness

- [ ] Tier A partial/fail/crash/untested 0
- [ ] edit/save/reopen/export E2E合格
- [ ] VoiceItem/speaker playback合格
- [ ] thumbnail/split/effects/media matrix合格
- [ ] DnD/clipboard合格
- [ ] workaroundのUI/documentation完了

### Update/diagnostics

- [ ] runtime update状態機械合格
- [ ] YMM4 update状態機械合格
- [ ] official updater Wine試験合格
- [ ] interrupted update/rollback合格
- [ ] process tree logging/redaction合格

### Legal/distribution

- [ ] release直前の最終監査書を読み完了
- [ ] UNKNOWN component 0
- [ ] license/notice/source義務とDMGが一致
- [ ] YMM4はexternal-only、CrossOver非同梱

### Signing/DMG

- [ ] Developer ID nested signing合格
- [ ] Hardened Runtime/entitlement合格
- [ ] notarytool Accepted
- [ ] stapler/spctl合格
- [ ] clean-machine/matrix合格
- [ ] final DMG hash固定、DMG添付

## 18. 中止条件

以下のどれかがあればDMG releaseへ進まない。

- 未特定crash/hang/memory corruption/data race
- 原因不明なWindows reference差
- GPU実使用の直接evidenceがない
- Tier Aのpartial/fail/crash/untested
- user project破損/無断変更
- unknown plugin ABI/frame/audio format
- source/component/license UNKNOWN
- Developer ID/notarization前提がない
- signing/Gatekeeper/clean-machine test失敗
- Git/source provenanceを確立できない

中止時は、完了範囲、再現手順、evidence、最小の次アクション、ユーザーから必要な入力を1つのblocker reportにまとめる。

## 19. 次回セッションの実行順

1. 必須文書を読む。最終監査書は開かない。
2. Git/source provenanceと外部前提を確認。
3. release-candidate input manifestを作成。
4. 通常build/testとcurrent runtime fixture gate。
5. sanitizer/leak/memory soak。
6. GPU/Metal traceとGPU実使用検証。
7. crash/stability matrixとWin32Service分離。
8. Tier A完全性とWindows reference比較。
9. バグごとにevidence→reproducer→修正→全回帰。
10. update/rollback/recovery/process diagnostics完了。
11. 新しいrelease candidate hashで全gateをやり直す。
12. ここで初めて最終ライセンス監査書を読む。
13. component inventory/release staging確定。
14. inner-to-outer signing、DMG、notarization、stapling、Gatekeeper。
15. clean-machine/macOS/hardware matrix。
16. final hashes/reportを固定しDMGを会話に添付。

DMGを先に作って後から中身を監査する進め方は禁止する。
