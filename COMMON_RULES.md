# YMM4M 共通ルール・開発記録

最終更新: 2026-08-30

この文書は、セッションをまたいで必ず共有する開発上の判断、確認済み事実、既知の問題、解決方法、現在の対応状況をまとめたものです。実行順は `NEXT_SESSION_HANDOFF.md`、簡潔な現況は `STATUS.md`、機械可読な判定は `compatibility/features.yaml` を参照してください。

保守・設計資料の正本:

- `docs/ARCHITECTURE_MAINTENANCE.md`: ownership、pin更新、UI、回帰、release運用
- `docs/RUNTIME_BOOTSTRAP_DESIGN.md`: 自動取得、hash検証、build、stage、prefix作成の設計とtrust boundary
- `docs/UPDATE_COMPATIBILITY_AUDIT.md`: runtime・prefix・YMM4更新耐性、atomic切替、残る制約
- `runtime/bootstrap.lock.json`: network取得物のURL、commit、SHA-256

## 1. 指示の優先順位と作業境界

1. ユーザーの最新の明示指示と `AGENTS.md` を最優先する。
2. YMM4 の未公開動作を推測しない。互換コードを変える前に、公開 API だけで再現できる証拠と再現手順を残す。
3. 法務レビューなしでプロプライエタリな YMM4 実装を逆コンパイルしない。
4. YMM4 本体、Microsoft の再配布権未確認ランタイムやフォント、CrossOver をリポジトリや配布物に含めない。
5. DXMT を MIT と扱わない。配布可否はリリース監査まで未決定とする。
6. Rosetta、SIP 無効化、Gatekeeper の全体無効化を恒久的な前提にしない。
7. WPF、D3D11、D3D12、WebView2 の問題を混同しない。FFmpeg と公式 YMM4 プラグイン API を優先する。
8. ユーザーのプロジェクトを黙って変更しない。すべての試験は分離したテスト用プロジェクトと専用 Wine prefix で行う。
9. macOS ホストは ARM64 のまま保ち、Wine/DXMT の変更は小さく、説明可能で upstream 可能な形にする。
10. リリース直前用の `YMM4M ライセンス監査・実装判断指示.md` は、ユーザー指定により通常開発中は開かない。全 Tier A ゲートを満たし、リリース候補を確定した最後の段階で初めて読み、その内容に従う。
11. 次回の全面監査・修正・DMG releaseは `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md` を主手順書とする。合格条件を満たさないdevelopment DMGをrelease-readyと扱わない。

## 2. 状態を記録するときのルール

- `compatibility/features.yaml` が現在の判定の正本である。許可される状態は `untested`、`pass`、`pass_with_workaround`、`partial`、`fail`、`crash`、`unsupported`。
- 過去の成功は「履歴」であり、同じ候補で新しい失敗が出た場合は現状を失敗へ更新する。`PROJECT001` の一時的な失敗と後続分離もこのルールに従い履歴と現状を分けて記録する。
- 回避策は直接成功と区別する。現在の `IME001` は `pass_with_workaround` であり、YMM4 内での直接 IME 入力成功ではない。
- 互換性の主張には、再現条件、入力、出力、ハッシュまたは画面証拠、反復回数を記録する。再現しない一度きりのクラッシュからパッチを作らない。
- YMM4 の公開ログに複数の例外が同時にある場合、時間的な近接だけで原因とみなさない。
- 診断ログと環境情報は資格情報を除去して保存する。秘密値、エージェントソケット、動的ローダー注入変数を子プロセスへ継承しない。

## 3. 現在の構成

### リポジトリ内

- SwiftPM による ARM64 macOS ホスト、core、bridge protocol、native encoder。
- `RuntimeBackend` 境界、安全な Rosetta/Wine 検出、無効化された ARM64/FEX 研究 backend。
- catalogで許可されたYMM4 ZIPの構造・容量・SHA-256検証、version別インストール、atomic current切替。
- M: 配下のメディアルート制約。
- バージョン付き・length-prefix・session-token 認証済み localhost bridge。
- raw video/audio の受信と形式検出。
- 環境情報と診断文の redaction。
- clean runtime の完全ハッシュ検証、prefix 安全性検証、WPF software profile。
- 明示同意後のWine/DXMT固定source取得、SHA-256検証、build、clean staging、専用prefix作成。
- ネイティブ日本語入力 overlay と、対象バージョン限定の Windows text helper。

### ローカル専用資産（コミット禁止）

- YMM4 Lite: `/Users/user/Library/Application Support/YMM4M/YMM4/lite-current/YukkuriMovieMaker.exe`
- clean runtime: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface`
- 専用 prefix: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix`
- Wine source: `/Users/user/Library/Application Support/YMM4M/Sources/wine-11.0`
- Wine source base: `db11d0fe6a169c457e23d007e20404643d067aa8`
- Wine build: `/Users/user/.ymm4m-dev/wine-build-x86_64`
- DXMT source: `/Users/user/Library/Application Support/YMM4M/Sources/dxmt`
- DXMT source base: `e55ad281c60be97f8815b5848e57cfd9f967d759`
- DXMT build: `/Users/user/.ymm4m-dev/dxmt-build`
- 分離テストプロジェクト: `/Users/user/.ymm4m-dev/test-projects`
- Xcode: `/Applications/Xcode.app/Contents/Developer`（Xcode 26.6）

YMM4 v4.55.1.1 Lite の ZIP と exe の期待ハッシュ、候補 runtime の全期待ハッシュは `runtime.lock.json` を正本とする。現候補の `winemac` full-file SHA-256は `d9ba183974c0ff023baa0fb02838e1943a2728e87491cc5b58961f9477e1a57f`、build間で安定したloadable-image SHA-256は `feec5cee6ad6f16368166a599ded5b4d9de7cb3a9653a7e3565c7f7c185b6508`。検証を外して起動してはならない。

旧 CrossOver 派生 runtime は比較証拠に限る。配布物の入力にも clean runtime の入力にも使わない。IME 調査用 runtime `/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-ime-trace` も証拠専用であり、リリースへ含めない。

## 4. 完了した実装と検証

### 安全な起動とホスト

- product backend と `tools/run-ymm4.sh` は allowlist された最小環境で起動する。
- 開発中、一度だけ直接起動した Wine がホスト環境を継承していることをプロセス情報から検出した。その試行は証拠から除外し、追跡対象リポジトリと保存済み分離プロジェクトを走査して秘密値がないことを確認した。
- 以後は `env -i` 相当のサニタイズ、runtime 内からのパス導出、root/home prefix 拒否を適用済み。資格情報そのものは記録しない。
- `pgrep -fal` のようにプロセスの環境由来情報を表示し得る確認方法は使わない。存在確認は表示を伴わない方法にする。

### グラフィックス互換層

確認した未修正 baseline:

- Wine 11.0 / 11.15 / CrossOver は CLI help まで到達する。
- WineD3D と D3DMetal は `ID2D1Device6.CreateDeviceContext` で停止。
- 未修正 DXMT は `IDXGISwapChain.GetBuffer(IID_IDXGISurface2)` で停止。

作成した小規模パッチ:

1. `patches/0001-dxmt-yymm4-compat.patch`
   - DXGI/D3D11 互換性を補い、`ArgumentEncodingContext` の compute device 初期化順を修正。
   - D3D11 device/compute/dispatch/readback を 100 回連続で通過。
2. `patches/0002-wine-d2d1-yymm4-compat.patch`
   - YMM4 が必要とする Direct2D device context、effects、bounds 等を公開 API reproducer に基づき補完。
   - Direct2D create/render/destroy を 15 回連続で通過。
3. `patches/0003-wine-dwrite-locale-fallback.patch`
   - Arial を起点にした日本語 locale fallback が Noto Sans CJK JP へ完全 glyph coverage で到達するよう修正。
   - empty locale と `ja-JP`、shared/isolated factory を公開 reproducer で確認。
4. `patches/0004-wine-macdrv-metal-view-bridge.patch`
   - Wine が管理する client surface に限定した小さい Metal view bridge。
   - top-level と child HWND を通し、DXMT preview を preview pane 内に閉じ込める。
   - 初版の独立 view は fixture を通したが WPF client 全体を覆ったため採用せず、既存 managed surface lifecycle に修正した。

clean Wine 11.0 + source-built DXMT 候補は 8 fixture suite を通過済み。D3D12 profile は無効のまま。

### WPF 表示

- clean GUI が白画面になった原因は、専用 prefix に `HKCU\\Software\\Microsoft\\Avalon.Graphics` の `DisableHWAcceleration=1` が欠けていたこと。
- 文書化された WPF software profile を適用すると、menu、item pane、preview、timeline、dialogue field を表示できた。
- これは Wine バイナリの不具合として扱わず、prefix 構成として backend が検査する。

### フォントと日本語描画

- Noto Sans CJK JP fallback 修正後、日本語文字列 `日本語テストABC123` は preview と H.264/AAC export の両方で豆腐化せず描画された。
- 日本語 project/export の画面と公開 reproducer は `evidence/dwrite-font-fallback-2026-08-26.md` に記録済み。

### メディアと書き出し

- PNG/JPEG を image path、WAV/MP3 を audio path、animated GIF を video path から公開 UI で import 済み。
- H.264/AAC video の import、preview decode/upload、save、過去時点の正常 reopen、matched-setting export を確認済み。
- FFmpeg software export は H.264/AAC、非無音 audio、所定フレーム配置を ffprobe/抽出フレームで確認済み。
- GIF は image button では拒否され、video button では `VideoItem` として保持され、export 内で異なる複数フレームを確認。
- video roundtrip 初回の `ReadbackToBuffer` 例外は、project と writer の寸法不一致が原因。寸法を一致させると成功し、失敗は Direct2D bitmap readback より前だったため D2D パッチを追加しなかった。
- GIF 試験中の DXMT pure-virtual / illegal-instruction は clean retry と3回の追加反復の計4回で再現せず、GIF 原因とはみなさずパッチも追加していない。3出力は byte-identical で、GIF 内の3時点はそれぞれ異なる decoded-frame hash になる。

### 日本語 IME

切り分け結果:

- YMM4 dialogue field は ASCII 入力に成功するが、直接の日本語 IME composition を受け取らない。
- 同じ Wine/prefix の Notepad は `日本語` を受け取る。
- YMM4 同梱 .NET 10.0.10 と同一ハッシュの PresentationCore/PresentationFramework を用いた公開 WPF TextBox reproducer も `日本語` を受け取る。
- 正しく YMM4 を前面にした Wine/macdrv trace では、marked text の進行と確定済み `日本語` が Wine content view まで届くが YMM4 field は変化しない。
- 前景アプリを誤った初回試行は破棄した。結論は「Wine macdrv/一般 WPF より上、YMM4 の input-control path 内」。YMM4 を逆コンパイルしておらず、Wine への推測パッチも入れていない。

実装済み回避策:

- ARM64 SwiftUI native input overlay で composition/editing を行う。
- `bridge/TextInput/win32-text-commit.c` helper が権限 0600 の一時 UTF-8 ファイルを最大 64 KiB 読み、`SendInput` の `KEYEVENTF_UNICODE` で明示確定した文字だけを対象 field へ送る。
- helper は YMM4 Lite 4.55.1.1 に限定し、Add を自動押下しない。timeout は 10 秒、一時ファイルは削除する。
- helper exe は `-Wl,--no-insert-timestamp` で再現可能だがローカル専用で、コミットしない。現在のローカル SHA-256 は `c57695530db4c754bedec54e57ad59bd2056441ab4adce7027fb63248d939112`。
- hiragana、katakana、candidate、Space、Enter、phrase、左右移動、Backspace、shortcut suppression の matrix が通過し、`日本語` を YMM4 field へ転送できた。
- よって `IME001` は `pass_with_workaround`。直接 IME が直ったとは記載しない。
- 試験後の macOS input source は ABC に戻してある。

### native overlay を用いた保存

- native overlay から `日本語` を field へ移し、YMM4 の公開 Add button で VoiceItem を作成、画面描画、分離 project 保存まで成功。
- project: `/Users/user/.ymm4m-dev/test-projects/ime-overlay-core-2026-08-27.ymmp`
- 保存時 SHA-256: `394ae203fc0d9f614cd1bfc61d06a760d19f785d75b141c0dcc88321fa7759ea`。公開 JSON 内に Serif の `日本語` が保持され、秘密値はない。

## 5. 既知の問題、解決状況、判断

| 項目 | 観測 | 現在の判断・対応 |
|---|---|---|
| `PROJECT001` project 再読込 | 空、Text-only、Text/Image/Audio は読み込み。保存済み日本語 Text/Image/Audio control は現候補・現 prefix で fresh Wine server ごとに 3/3 再読込成功 | **pass**。過去の2失敗 control はどちらも vanilla YMM4 Lite に含まれない AquesTalk1 を選択しており、一般 project loader ではなく AquesTalk1 owner-modal へ進んでいた |
| AquesTalk1 VoiceItem | 公開 character settings で `AquesTalk1VoiceParameter` を選択した project は `AquesTalk1` owner-modal へ進み、現候補では内容面が黒く MSAA child もない | vanilla Lite では **unsupported**。公式仕様上 AquesTalk は別途 plug-in。ライセンスとコンポーネント範囲に関わるため通常開発では導入せず、最終 release 監査まで分離する |
| YMM4 内の直接 IME | Wine content view までは確定文字が届くが dialogue field が更新されない | 直接入力は未解決。version-scoped native overlay により `pass_with_workaround` |
| `YukkuriMovieMaker.Win32Service.exe` | GUI 起動時に Mono native crash banner。公開 log に WMI 初期化失敗 | main window と主要試験は進行するが service の役割と機能影響は未特定。推測回避策なし |
| Community Explorer | `ExplorerViewModel.Refresh` の `ObjectDisposedException` | project reopen 失敗との因果関係なし。ログが近いだけで原因扱いしない |
| GIF 中の一度の native stop | DXMT pure virtual / illegal instruction を一度観測、後続の統制4回で非再現。追加3出力は byte-identical | 再現しない過去観測として証拠保持。GIF 原因とせず compatibility 変更なし |
| Video export readback | 寸法不一致で `ArgumentOutOfRangeException` | project/writer 寸法を一致させて解決。D2D 問題ではない |
| WPF 白画面 | prefix に software profile がなかった | `DisableHWAcceleration=1` を prefix に設定し解決。backend が検査 |
| DXMT child preview が UI を覆う | 初版の非管理 Metal view の lifecycle が不適切 | Wine managed client surface に結び付けて解決 |
| 旧 CrossOver 派生候補 | 開発比較には使えたが配布不可 | clean Wine 11.0 + source-built Wine/DXMT に置換。旧 root は配布禁止 |

現在未完了の検証は、Lite-supported voice engine を使った VoiceItem 再読込・編集、video thumbnail と split の保存・再読込、speaker からの可聴再生、effects、残りの media formats、Windows reference export 比較である。AquesTalk1 modal の分離、GIF 反復、Finder `.ymmp` 起動は完了済みである。

## 6. 現在の機能判定

- `core.ui.ime`: `pass_with_workaround`
- `core.project.save-reopen`: `pass`
- `core.finder.open-project`: `pass`
- `core.timeline.edit`: `partial`
- import/export を含むメディア系: 主に `partial`
- CLI/help と低レベル fixture: `pass`

詳細は必ず `compatibility/features.yaml` を読む。プロジェクトは Discovery / pre-alpha であり、`v1.0` または `milestone-core-workflow` を付けてはならない。

## 7. 検証済みの品質ゲート

直近で次を通過している。

- `swift build`
- `swift run YMM4MContractTests`
- Python unit tests 14 件
- `python3 tools/validate-compatibility.py`（20 feature）
- `sh -n tools/run-ymm4.sh`
- `git diff --check`
- tracked repository の credential scan: 0 件
- 専用 prefix shutdown 後の YMM4 process: なし
- macOS input source: ABC

2026-08-29 の全面監査追加ゲートでは、Swift warning-as-error、ASan、TSan、`-Wall -Wextra -Werror` 付き 8 fixture、compute 100/100 が合格した。Metal System Trace は DXMT compute fixture に 200 command-buffer submission、300 encoder、300 GPU interval、command-buffer error 0 を直接記録した。これは低レベル GPU 実使用の証明であり、実 YMM4 の全描画 matrix 完了とは扱わない。C# gate は `dotnet` SDK 不在で未実施。詳細は `evidence/full-audit-gates-2026-08-29.md`。

コードや文書を変更したセッションでは、変更範囲に応じて再実行し、結果を新しい evidence に残す。

## 8. 証拠の索引

- `evidence/wpf-ime-managed-surface-2026-08-27.md`: managed surface、WPF software profile、IME 切り分け、基本 overlay gate
- `evidence/ime-overlay-core-workflow-2026-08-27.md`: overlay から Add/save、当時観測した reopen regression の履歴
- `evidence/upstream-wine-dxmt-metal-view-2026-08-26.md`: clean runtime、Metal view bridge、Win32Service 観測
- `evidence/dwrite-font-fallback-2026-08-26.md`: 日本語 fallback と描画/export
- `evidence/dxmt-compute-device-init-2026-08-26.md`: compute 初期化順と 100 回試験
- `evidence/ymm4-lite-video-roundtrip-2026-08-26.md`: video import/export と寸法不一致の解決
- `evidence/ymm4-lite-jpeg-mp3-gif-2026-08-26.md`: JPEG/MP3/GIF と非再現 stop
- `evidence/project-reopen-isolation-2026-08-28.md`: PROJECT001 3/3 pass と AquesTalk1 optional-plugin 軸の分離
- `evidence/runtime-fixture-regression-2026-08-28.md`: 自動 runner による現 runtime 8 fixture 再試験
- `evidence/ymm4-lite-gif-repeat-2026-08-28.md`: GIF/JPEG/MP3 matched-setting export 3回の byte-identical 反復
- `evidence/ymm4-lite-video-split-2026-08-28.md`: video frame-0 preview、in-memory split、Save As picker 分離
- `evidence/finder-integration-2026-08-29.md`: Finder `.ymmp` intake、安全な M: mapping、version gate、ARM64 development bundle
- `evidence/version-management-2026-08-29.md`: version directory を保持する atomic switch/rollback primitive
- `evidence/quality-gates-2026-08-29.md`: host/tooling 全テスト、process/input-source cleanup、Git index の状態
- `evidence/setup-ui-development-dmg-2026-08-30.md`: 4ステップ設定UI、UI選択prefix、Mac導入ガイド、development DMG build 2
- `evidence/automatic-runtime-prefix-bootstrap-2026-08-30.md`: 固定source取得、FreeType有効Wine/DXMT build、再現可能PE、新規prefixの8 fixture
- `evidence/development-dmg-build3-2026-08-30.md`: bundle完成後のad-hoc署名、DMG内容監査、build 3 artifact
- `evidence/update-resilience-zip-launch-v0.1.0-2026-08-30.md`: versioned runtime/prefix/YMM4、実公式ZIP導入、v0.1.0 development gate
- `evidence/baseline-2026-08-24.md`: 未修正 backend の baseline
- `runtime.lock.json`: tested YMM4/runtime のハッシュ正本
- `STATUS.md`: 人間向け現況
- `compatibility/features.yaml`: 機能判定の正本

## 9. リリースまで残る大項目

- Lite-supported item set で通った `PROJECT001` を維持し、supported voice engine を使う VoiceItem 再読込・編集を完了する。
- Tier A の編集・メディア・再生・export・Windows reference 比較を完了する。
- clean runtime の component/source inventory と配布判断を確定する。
- Developer ID と必要 entitlement を確認する。
- Developer ID 署名はユーザー確認により利用不可。署名・公証済み release-ready DMG を作成しない。リリース外の監査結果と開発用未署名 bundle は pre-alpha として明示する。
- signing、notarization、packaging、update/rollback、crash recovery を実装・検証する。
- その後、リリース直前に限り、保留中のライセンス監査文書を初めて読み、監査・実装判断を完了する。
