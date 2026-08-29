# 次セッション引き継ぎ

最終更新: 2026-08-30

## 次回セッションの主作業書

次回は `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md` を主手順書とし、メモリ安全性、GPU描画/GPU実使用、クラッシュ安定性、Tier A完全性を全面監査する。問題は証拠→最小reproducer→修正→全回帰の順に処理する。すべてのrelease gateと最終ライセンス監査が合格した場合に限り、署名・公証済みDMGを作成して会話に添付する。

## ゴール

次セッションのゴールは、現在のpassを維持しながら、メモリ安全性、GPU描画とGPU実使用、クラッシュ安定性、Tier A完全性を全面監査し、発見したバグを修正することです。全gate、外部前提、最終ライセンス監査が合格した場合に限り、release-readyな署名・公証済みDMGまで仕上げます。AquesTalkはLiteに同梱されずlicense範囲に関係するため、無断で追加しません。

## 開始時に読む順番

1. `AGENTS.md`
2. `COMMON_RULES.md`
3. この文書
4. `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md`
5. `STATUS.md`
6. `compatibility/features.yaml`
7. `evidence/ime-overlay-core-workflow-2026-08-27.md`
8. `evidence/project-reopen-isolation-2026-08-28.md`
9. `evidence/wpf-ime-managed-surface-2026-08-27.md`
10. 必要になった対象別 evidence

`YMM4M ライセンス監査・実装判断指示.md` は開かない。これは全開発・Tier A 検証を終えた release 直前専用である。

## 現在の作業地点

- clean runtime と WPF software profile で YMM4 Lite 4.55.1.1 の UI、preview、native overlay、Add、save までは動く。
- overlay から作成した `日本語` VoiceItem は公開 JSON に正常保存されたが、既定 character は `AquesTalk1VoiceParameter` を選択する。
- 以前の両失敗 control は一般的な project loader 停止ではなく、vanilla Lite にない AquesTalk1 の owner-modal に進んでいた。現候補でその WPF content が黒く、MSAA child はない。
- 空、Text-only、Text/Image/Audio project は再読込に成功。現 runtime・現 prefix で保存済み日本語 Text/Image/Audio control は fresh Wine server ごとに 3/3 pass。
- `PROJECT001` は Lite-supported item set で `pass`。AquesTalk1 は現 component set で `unsupported`。
- native host は `.ymmp` intake、安全な `M:` mapping、実行ファイル hash gate、unsigned ARM64 development bundle 作成まで実装済み。LaunchServices から isolated `.ymmp` を開き、公開設定の `M:` path と元 hash 不変まで確認して `pass`。
- versioned YMM4 directory を残したまま `current` symlink を原子的に切り替える rollback primitive は unit test 済み。公式 updater の Wine 動作、update UI、interrupted recovery、YMM4M runtime updater は未完了。
- 2026-08-29 の host/tooling gate は Swift、contract、Python 14件、compatibility 18項目、lock、shell/plist、credential scan、process cleanup、ABC input source まで pass。Git index は空で、repository 全体が untracked のため commit は作っていない。
- WMI 初期化失敗、Win32Service crash banner、Community Explorer disposal exception は成功対照でも出るため reopen 原因としては帰属しない。
- 2026-08-29 全面監査で Swift warning-as-error/ASan/TSan、warning-as-error 付き 8 runtime fixture、compute 100/100 が合格。Metal System Trace で低レベル DXMT compute の GPU 実使用を直接確認した。
- Tier A の drag-and-drop と clipboard が registry から漏れていたため、`DND001` / `CLIP001` を `untested` で追加。未検証のまま pass にしない。
- Developer ID 署名はユーザー確認により利用不可。署名・公証・stapling・Gatekeeper release gate と release-ready DMG 作成は停止。最終 license 監査書は未開封のまま。
- C# warning gate は `dotnet` SDK 不在で未実施。詳細と trace inventory hash は `evidence/full-audit-gates-2026-08-29.md`。
- native host は、runtime、専用prefix、YMM4 exe、project/media root の4ステップUIと、設定確認、YMM4直接起動、project picker を実装済み。UI選択prefixは従来と同じsanitized backendで検証される。
- Macでの開き方は `docs/MAC_SETUP.md`、UI・DMG実測は `evidence/setup-ui-development-dmg-2026-08-30.md`。development build 2 DMGは `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-prealpha2-development-adhoc.dmg`。release-readyではない。

対象 project:

- AquesTalk1 分離 control: `/Users/user/.ymm4m-dev/test-projects/ime-overlay-core-2026-08-27.ymmp`
- AquesTalk1 を含む複合 control: `/Users/user/.ymm4m-dev/test-projects/core-text.ymmp`
- PROJECT001 3/3 pass control: `/Users/user/.ymm4m-dev/test-projects/core-japanese-noto.ymmp`
- 最小 overlay 保存試験が必要なら、分離ディレクトリ内に新しい名前で作る。既存ファイルを上書きしない。

## 安全な起動条件

通常の GUI 起動は `tools/run-ymm4.sh` を使う。raw Wine を直接起動する場合も、同スクリプトと同等の空環境 allowlist を明示できる診断時に限る。

設定値:

```sh
YMM4M_WINE='/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface/bin/wine'
YMM4M_PREFIX='/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix'
YMM4M_EXE='/Users/user/Library/Application Support/YMM4M/YMM4/lite-current/YukkuriMovieMaker.exe'
YMM4M_WINEDEBUG='-all'
```

スクリプトは host credentials、agent sockets、loader injection を継承させず、root/home prefix を拒否する。検証を迂回しない。

開始前と終了後:

- 専用 prefix の YMM4/Wine process が残っていないことを、command line や環境値を表示しない方法で確認する。
- macOS input source が ABC であることを確認する。
- system 全体の Wine や他アプリを広範囲に終了しない。

## 完了済みの PROJECT001 診断手順

以下は 2026-08-28 に実施済み。結果と実測値は
`evidence/project-reopen-isolation-2026-08-28.md` を正とし、この手順を未着手として繰り返さない。

### 1. 現状を保存する

- current prefix と対象 project のパス、hash、更新時刻を記録する。
- current prefix を破壊・初期化しない。変更が必要なら、明示的な新規パスへ複製または fresh prefix を作る。
- 既存 test project を編集せず、reopen だけで観測する。

### 2. 同一 runtime で prefix 軸を分離する

- current prefix + `core-text.ymmp` を一度、決めた timeout と画面観測で再現する。
- 同じ clean runtime から fresh dedicated prefix を新しい明示パスに作る。
- fresh prefix に、既存の文書化された WPF software profile と必要な font setup だけを適用する。
- fresh prefix + `core-text.ymmp`、fresh prefix + overlay project を同じ条件で試す。
- current と fresh の差は registry/config/plugin inventory の公開範囲を hash/一覧化して比較する。秘密や user project content は証拠へ混ぜない。

判定:

- fresh だけ成功: prefix state regression。差分を一項目ずつ再現し、最小の構成修正にする。
- fresh も失敗: runtime または現在の YMM4/外部条件側を疑うが、まだ断定しない。
- project ごとに差が出る: public JSON schema、item 種別、media/voice 参照など公開データだけで最小化する。

### 3. project 内容の軸を分離する

必要なら、公開 UI だけで次の分離 project を新規作成する。

1. 空または最小 project
2. ASCII TextItem のみ
3. 日本語 TextItem のみ
4. VoiceItem のみ
5. Image/Audio/Video を一種類ずつ

保存、正常終了、再起動、reopen を同じ手順で行う。YMM4 独自内部実装を推測せず、公開 JSON と UI の差だけを記録する。

### 4. runtime 軸を分離する

fresh prefix でも control が失敗する場合:

- `runtime.lock.json` の hash 検証を再実行する。
- 現 clean candidate と、過去に成功したことが証拠化された再現可能 runtime staging の構成差を調べる。
- CrossOver 派生 root を clean 候補として再利用しない。
- 候補を変えた場合、8 fixture suite、WPF 表示、100 compute iterations、top-level/child HWND を先に再検証してから YMM4 reopen を試す。

### 5. ログの扱い

- 最初は YMM4 公開 log、window state、経過時間、exit status を採る。
- Wine debug channel は問題層に限定し、サニタイズ済み環境で採る。WPF、D3D11、D3D12、WebView2、filesystem、process を一つの原因として混ぜない。
- WMI、Win32Service、Community Explorer の既知メッセージは、reopen 成否との対照試験で相関が出るまで原因にしない。
- 新しい workaround や compatibility patch は、公開 API reproducer と対照試験が揃ってから作る。

## 次に進む順番

1. 公式対応一覧とローカル構成から、vanilla YMM4 Lite で現実に使える voice engine を特定する。購入、API key、アカウント、別 license が要るものは勝手に導入しない。
2. supported engine があれば native overlay の `日本語` を公開 Add → save → 正常終了 → 再起動 → reopen まで一連で証拠化する。なければ VoiceItem を外部条件 blocker として残し、TextItem で edit matrix を進める。
3. reopen 後に item の duplicate、move、trim/split、delete、undo/redo、日本語変更を検証する。
4. timeline/edit の `partial` を項目別に更新する。
5. メディア残件を次の順で進める。
   - speaker からの可聴 playback
   - video thumbnail と split の保存・再読込
   - 残りの画像・音声・動画形式
   - effects
   - Windows reference export との比較
6. 各検証後に `evidence/`、`STATUS.md`、`compatibility/features.yaml` を同時更新する。
7. `FINDER001` は完了済み。`.ymme` の自動導入は検証済みとみなさず、挙動を推測しない。

## 実装・検証後の共通チェック

変更範囲に応じ、最低限次を行う。

```sh
swift build
swift run YMM4MContractTests
python3 -m unittest discover tests
python3 tools/validate-compatibility.py
sh -n tools/run-ymm4.sh
git diff --check
```

加えて、tracked repository の credential scan、runtime hash validation、専用 prefix process の終了、macOS input source が ABC であることを確認する。失敗があれば「以前通った」ことを理由に pass のままにしない。

## リリースへ進める条件

- `PROJECT001` と、ライセンス上利用可能な supported-item core workflow が current clean candidate で反復 pass。
- Tier A の未完項目が証拠付きで完了。
- runtime source/component inventory と配布方針が確定。
- signing、notarization、packaging、update/rollback、crash recovery が実装・検証済み。
- Developer ID と必要 entitlement が利用可能。

これらが揃った最後の段階でのみ、保留中のライセンス監査文書を読み、その指示に従って release 可否を判断する。それまでは pre-alpha のままにする。
