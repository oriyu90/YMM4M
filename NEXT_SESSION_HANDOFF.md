# 次セッション完全引き継ぎ書

最終更新: 2026-08-30

## 0. この文書の目的

次回セッションは調査だけで終わらせず、残課題を証拠に基づいて修正し、回帰試験、文書更新、commit/pushまで完了する。この文書は現在の作業地点、変更してよい範囲、ローカル資産、再現コマンド、優先順位、完了条件を一つにまとめた実行用備忘録である。

## 1. 開始時に必ず読む順番

1. `AGENTS.md`
2. `COMMON_RULES.md`
3. この文書を最後まで
4. `STATUS.md`
5. `compatibility/features.yaml`
6. `docs/UPDATE_COMPATIBILITY_AUDIT.md`
7. `docs/ARCHITECTURE_MAINTENANCE.md`
8. `docs/RUNTIME_BOOTSTRAP_DESIGN.md`
9. `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md`
10. 修正対象に対応する`evidence/`文書

`YMM4M ライセンス監査・実装判断指示.md`はユーザー指定により通常開発中は開かない。全Tier A、配布、署名・公証、安定性gateが揃い、最終pre-release判断を行う直前に限って読む。現在はその段階ではない。

## 2. Git・GitHub・Releaseの現在値

- Repository: `https://github.com/oriyu90/YMM4M`（private）
- Branch: `codex/automatic-runtime-setup`
- この引き継ぎ書作成前の基準HEAD: `61e73fbeef81ad514caf12a9e1e57f167b1c62b9`。次回は`git rev-parse HEAD`で最新値を確認する。
- Implementation commit: `db8e238939c1fec9be9f23f269e2f8f3bbf28ebd`
- Upstream: `origin/codex/automatic-runtime-setup`
- 基準HEADのCI: run `33274703783`、native/bridge-protocolともpass
- 基準CI URL: `https://github.com/oriyu90/YMM4M/actions/runs/33274703783`
- GitHub draft release ID: `379098975`
- Draft tag: `v0.1.0`
- Draft title: `YMM4M v0.1.0 development candidate`
- Draft state: `draft=true`, `prerelease=true`、未公開
- 現在のdraft preview URL: `https://github.com/oriyu90/YMM4M/releases/tag/untagged-2e3cca54a841d3d7d4cb`
- Draft URLの`untagged-*`部分はmetadata編集で変わるため、正本はrelease IDと`gh api repos/oriyu90/YMM4M/releases/379098975`で確認する。

worktreeで意図的に未追跡のファイルは、延期中の監査書だけである。追加・commit・内容確認をしてはならない。

```text
YMM4M ライセンス監査・実装判断指示.md
```

作業開始時に`git status --short`を確認する。上記以外の差分があれば、ユーザーの変更かを判断し、勝手に破棄しない。

## 3. v0.1.0 development成果物

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-development-adhoc.dmg`
- DMG size: `607858` bytes
- DMG SHA-256: `9bc7987d87f967fa967382f110a1dfe0064a2a634d1130a03ee4e2e57df3e2de`
- Bundle: `CFBundleShortVersionString=0.1.0`, `CFBundleVersion=4`, ARM64
- Signature: explicit ad-hoc、`TeamIdentifier=not set`
- Developer ID: 利用不可（ユーザー確認済み）
- Notarization/stapling: 未実施・実施不可
- Gatekeeper通常配布: 不合格を前提とする

DMGにはYMM4、Wine/DXMT binary、CrossOver、Microsoft runtime/font、voice engine、test mediaを含めていない。GitHub assetのdigestとsizeはローカルDMGに一致している。これはdevelopment評価用でありrelease-readyではない。

同じ出力pathへ再buildするとき、build scriptは上書きを拒否する。既存成果物を黙って削除せず、新しいbuild番号/pathを使うか、保持先へ明示的に退避する。

## 4. 今回までに完成した更新耐性

### Runtimeとprefix

- Runtime profile: `wine-11.0-dxmt-e55ad281-patchset4`
- Prefix schema: `2`
- 標準active runtime: `~/Library/Application Support/YMM4M/Runtimes/current`
- version runtime: `~/Library/Application Support/YMM4M/Runtimes/versions/wine-11.0-dxmt-e55ad281-patchset4`
- 標準active prefix: `~/Library/Application Support/YMM4M/Prefixes/current`
- version prefix: `~/Library/Application Support/YMM4M/Prefixes/versions/wine-11.0-dxmt-e55ad281-patchset4-prefix-v2`
- prefixの`ymm4m-runtime-binding.json`へruntime profileとschemaを記録する。
- runtimeとprefixを完成・検証してから`current` symlinkをatomicに切り替える。
- 片側だけ切り替わった場合はbinding不一致で起動を拒否し、次回setupで修復する。
- 旧単一配置`Runtimes/ymm4m-wine-11.0-dxmt`と`Prefixes/YMM4`は、明示setup時に検証後version storeへ移行する。
- 手動・開発者向けcustom pathはversion bindingを要求しないが、runtime hash、prefix安全性、WPF profile検証は迂回しない。

主要実装:

- `app/YMM4M/Runtime/RuntimeBootstrapper.swift`
- `app/YMM4M/Integration/VersionedDirectoryChannel.swift`
- `app/YMM4M/Runtime/RosettaWineBackend.swift`
- `runtime/bootstrap.lock.json`
- `runtime.lock.json`

### YMM4 ZIP

- 対応カタログ: `compatibility/ymm4-releases.json`
- 現在known-compatible: `4.55.1.1-Lite`
- Official ZIP SHA-256: `125860147cc33b831fc1a6d6ea996958001c2ead3b0d37f7d900251d5617db9b`
- EXE SHA-256: `96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822`
- Required runtime profile: `wine-11.0-dxmt-e55ad281-patchset4`
- 標準store: `~/Library/Application Support/YMM4M/YMM4`
- version install: `YMM4/versions/4.55.1.1-Lite`
- active channel: `YMM4/current`

`YMM4ArchiveInstaller`は次を検査する。

- ZIP全体と展開後exeのSHA-256
- 最大archive 2 GiB、展開後4 GiB、最大20,000 entries
- absolute path、`..`、control character、重複名、暗号化entry
- local/central filename不一致、symlink、許可されない展開後file type
- ZIP64は現時点で未対応として拒否

未知のZIP、unknown/known-broken classification、managed install内でhashが変わったexeは起動しない。将来版を推測互換にしない。

主要実装:

- `app/YMM4M/Launcher/YMM4ArchiveInstaller.swift`
- `app/YMM4M/Launcher/YMM4CompatibilityPolicy.swift`
- `app/YMM4M/App/YMM4MApp.swift`
- `compatibility/ymm4-releases.json`

### UI

通常利用者の操作順は次のとおり。

1. 第三者software取得・buildへの説明を確認して同意
2. `互換環境を自動セットアップ`
3. `ZIPを選んで準備`で公式YMM4 ZIPを選ぶ
4. `1. 設定を確認`
5. `2. YMM4をMacで開く`

最後のボタンはWine上のYMM4をmacOS windowとして開く。展開済みexe、runtime、prefixの手動選択は詳細設定・開発者向けに残している。projectを開く場合は専用media rootを先に選び、contained `.ymmp`だけを`M:`経由で渡す。

## 5. ローカル専用資産と禁止事項

次はローカル試験専用でありcommit禁止。

- Official ZIP: `/Users/user/places/Project/YMM4移植/YukkuriMovieMaker_v4_Lite.zip`
- Existing YMM4 exe: `/Users/user/Library/Application Support/YMM4M/YMM4/lite-current/YukkuriMovieMaker.exe`
- Clean runtime: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface`
- Dedicated prefix: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix`
- Wine source: `/Users/user/Library/Application Support/YMM4M/Sources/wine-11.0`
- Wine source base: `db11d0fe6a169c457e23d007e20404643d067aa8`
- Wine build: `/Users/user/.ymm4m-dev/wine-build-x86_64`
- DXMT source: `/Users/user/Library/Application Support/YMM4M/Sources/dxmt`
- DXMT source base: `e55ad281c60be97f8815b5848e57cfd9f967d759`
- DXMT build: `/Users/user/.ymm4m-dev/dxmt-build`
- Isolated projects: `/Users/user/.ymm4m-dev/test-projects`
- Xcode: `/Applications/Xcode.app/Contents/Developer`（Xcode 26.6）

禁止事項:

- YMM4 binary/ZIP、Microsoft proprietary runtime/font、CrossOverをcommit/DMGへ入れない。
- DXMTをMITとして扱わない。
- proprietary YMM4を逆コンパイルしない。
- SIP/Gatekeeperを全体無効化しない。
- 既存project/prefix/runtimeを黙って変更・初期化・上書きしない。
- 未検証hashを通すためにvalidationを弱めない。
- WPF、D3D11、D3D12、WebView2、Win32Serviceの問題を一つにまとめない。

## 6. 現在確認済みの機能

- `PROJECT001`: Lite-supported Text/Image/Audio setで3/3 reopen pass
- Finder `.ymmp` open: pass。source project hash不変、contained `M:` mapping
- YMM4 UI: menu、item pane、preview、timeline、dialogue field表示
- WPF: `DisableHWAcceleration=1`をprefix profileとして検証
- 日本語font: Noto Sans CJK JP fallback、preview/exportで欠字なし
- Import: PNG/JPEG、WAV/MP3、animated GIF、H.264/AAC
- Export: FFmpeg software H.264/AAC、非無音audio、画像/日本語描画
- Runtime fixtures: 8/8、compute 100/100、top-level/child HWND、D2D/DWrite
- Native IME overlay: `日本語`の確定文字転送、Add/saveまで
- IMEの正確な判定: `pass_with_workaround`。YMM4 fieldへの直接IME成功ではない
- Official YMM4 ZIP実物を使ったhash、安全展開、version install/current switch contract: pass
- v0.1.0 app GUI起動・clean quit、DMG read-only mount、署名、禁止payload scan: pass

現在の機械可読判定は必ず`compatibility/features.yaml`を正とする。過去のpassより新しいfailureを優先する。

## 7. 既知問題と原因を誤認しないためのメモ

### AquesTalk1

旧reopen失敗controlはvanilla Liteに含まれないAquesTalk1を選択し、owner-modalへ進んでいた。一般project loader failureではない。現component setでは`unsupported`。購入、plugin導入、license判断を無断で行わない。

対象:

- `/Users/user/.ymm4m-dev/test-projects/ime-overlay-core-2026-08-27.ymmp`
- `/Users/user/.ymm4m-dev/test-projects/core-text.ymmp`

正常対照:

- `/Users/user/.ymm4m-dev/test-projects/core-japanese-noto.ymmp`

### Direct IME

同じWine/prefixのNotepadとruntime-matched standalone WPF TextBoxは日本語IMEに成功する。YMM4 Wine content viewまでは確定文字が届くがdialogue fieldが更新されない。YMM4 input-control path内まで切り分け済み。推測Wine patchを作らず、native overlayをversion限定workaroundとして維持する。

### Win32Service/WMI

`YukkuriMovieMaker.Win32Service.exe`のMono native crash bannerとWMI初期化失敗がある。main windowや成功workflowでも出るため、他の失敗原因と断定しない。serviceの役割と機能影響は未特定。

### Community Explorer

`ExplorerViewModel.Refresh`の`ObjectDisposedException`は成功対照でも観測され、project reopen失敗との因果関係はない。

### GIF native stop

DXMT pure-virtual/illegal-instructionを一度だけ観測したが、統制4回で非再現、追加3 exportはbyte-identical。再現可能になるまでpatch原因にしない。

### Save As picker

video splitのin-memory変更は確認できたが、custom WPF Save As pickerがblank surfaceでpersisted split/reopenは未完。WPF一般表示passと同一問題にしない。

## 8. 次回の修正優先順位

### P0: 更新・回復UIを完成させる

目的: 今回実装したversion保持を、利用者が安全に回復へ使えるようにする。

実装候補:

1. installed runtime/prefix/YMM4 version一覧を読み取り専用で表示する。
2. binding/catalog/hashが合う旧組合せだけをrollback候補にする。
3. `current`が壊れている、store外を指す、non-symlinkの場合は自動上書きせず明確に停止する。
4. rollbackは確認ダイアログ後にatomic switchし、切替後に全validationを再実行する。
5. interrupted switch、missing target、tampered executable、mismatched runtime/prefixをcontract testへ追加する。
6. 既存version directoryは削除しない。cleanup機能は別設計にする。

完了条件:

- 正常rollback、改変version拒否、store外拒否、片側切替のself-repairを自動testで再現。
- UI文言が何を選び何が変わるか説明する。
- `docs/UPDATE_COMPATIBILITY_AUDIT.md`、`STATUS.md`、evidenceを同時更新。

### P0: AppStorageと旧layout migrationを強化する

目的: v0.1.0以前に保存された実体pathがupdate後も旧versionを指し続けないようにする。

確認・修正候補:

1. 起動時に保存済み標準旧pathを識別する。ただし任意custom pathと誤認しない。
2. 自動migrationは実体を動かさず、まずsetupを促す表示にするか、明示同意後だけ行う。
3. automatic setup成功後はAppStorageを必ず`current` channelへ正規化する。
4. environment overrideは永続設定を書き換えない。
5. migrationの再実行・途中失敗をidempotent testする。

完了条件:

- build 3以前の保存設定をfixture化し、旧path→新channelの安全な導線が自動testでpass。

### P1: catalog更新設計

現在はbundle内catalogだけを信頼する。単なるremote JSONの自動fetchは実装しない。remote更新を行うなら、署名、key rotation、rollback/freeze protection、schema version、atomic cache、offline fallback、失効方針を先に設計する。実装が大きい場合は、v0.1.xでは「アプリ更新でcatalog更新」を維持する方が安全。

完了条件:

- trust modelが文書化され、署名検証を迂回する経路がない。
- 署名方式を確定できなければ実装せず、現状を明示する。

### P1: Win32Service crashの機能影響を分離する

1. 公開log、process exit、window stateだけから、serviceが担当する公開機能を一つずつ対照試験する。
2. WMI、WebView2、media、voice、project処理を別軸で記録する。
3. 公開reproducerなしにWine/WPF patchを追加しない。
4. 原因不明なら未解決として残す。

### P1: Tier A編集・メディア残件

1. Liteで利用可能なsupported voice engineの有無を公式情報とローカル構成から確認。追加license/account/purchaseは無断で行わない。
2. TextItemでduplicate、move、trim/split、delete、undo/redo、日本語変更。
3. video thumbnail、split、save/reopen。
4. speakerからの可聴playback。
5. effects、残りformats。
6. Windows reference export比較。
7. drag-and-drop `DND001`、clipboard `CLIP001`。

各項目は一つずつ再現条件、入力hash、出力、反復回数を証拠化する。

### P2: Direct IME

native overlayは動作しているため、推測修正を優先しない。公開API再現条件またはYMM4公式入力経路の情報が得られた場合だけ再開する。直接IMEを直せていない状態を`pass`へ変更しない。

## 9. 安全な起動・試験コマンド

通常のYMM4診断起動:

```sh
YMM4M_WINE='/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface/bin/wine' \
YMM4M_PREFIX='/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix' \
YMM4M_EXE='/Users/user/Library/Application Support/YMM4M/YMM4/lite-current/YukkuriMovieMaker.exe' \
YMM4M_WINEDEBUG='-all' \
tools/run-ymm4.sh
```

raw Wine起動は同じallowlistを明示できる診断時に限る。host credentials、agent sockets、`DYLD_*`などloader injectionを継承させない。`pgrep -fal`のようにcommand line/environmentを表示し得る確認を使わず、`pgrep -x YMM4M >/dev/null`のような存在確認に留める。

Runtime fixtures:

```sh
YMM4M_WINE='/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface/bin/wine' \
YMM4M_PREFIX='/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix' \
tools/run-runtime-fixtures.sh
```

実公式ZIP contract:

```sh
YMM4M_ARCHIVE_TEST="$PWD/YukkuriMovieMaker_v4_Lite.zip" \
YMM4M_YMM4_CATALOG="$PWD/compatibility/ymm4-releases.json" \
swift run YMM4MContractTests
```

この試験は一時storeを使う。YMM4 ZIPを編集・commitしない。

## 10. 最低限の回帰gate

コード変更後:

```sh
swift build -Xswiftc -warnings-as-errors
swift run YMM4MContractTests
python3 -m unittest discover -s tests/unit -p 'test_*.py'
python3 tools/validate-runtime-lock.py
python3 tools/validate-compatibility.py
sh -n tools/build-app.sh tools/build-development-dmg.sh \
  tools/bootstrap-wine-dxmt-runtime.sh tools/create-prefix.sh \
  tools/configure-japanese-fonts.sh tools/setup-prefix-from-runtime.sh \
  tools/stage-clean-wine-dxmt-runtime.sh
plutil -lint app/YMM4M/Resources/Info.plist
git diff --check
```

現baseline:

- Swift warnings-as-errors: pass
- Swift contracts: pass
- Python unit: 16/16
- compatibility registry: 20 features validate
- 実公式ZIP contract: pass
- runtime fixtures: 8/8、compute 100/100
- GitHub CI: nativeとbridge protocol pass

Runtime/patch/prefixを変更したら8 fixtureとcompute 100回を必ず再実行する。YMM4 workflowに関わる変更なら実YMM4の対象workflowも分離projectで再実行する。DMGを作る場合は、read-only mount、strict codesign、ARM64、catalog同梱hash、禁止payload scan、GUI launch/clean quitまで行う。

終了時:

- 専用prefixのYMM4/Wine processが残っていないこと。
- macOS input sourceがABCであること。
- tracked credential pattern scanが0件であること。
- `compatibility/features.yaml`、`STATUS.md`、evidenceが同じcandidateを示すこと。

## 11. 文書更新ルール

修正時は最低でも次を同期する。

- 機械可読な現在結果: `compatibility/features.yaml`
- 人間向け状態: `STATUS.md`
- 恒久判断・証拠索引: `COMMON_RULES.md`
- 次回作業地点: この文書
- 変更履歴: `CHANGELOG.md`
- 再現条件・hash・結果: 新しい`evidence/*.md`
- 更新設計を変えた場合: `docs/UPDATE_COMPATIBILITY_AUDIT.md`
- runtime取得/buildを変えた場合: `docs/RUNTIME_BOOTSTRAP_DESIGN.md`とlock files
- UI手順を変えた場合: `docs/MAC_SETUP.md`と`README.md`

互換性claimはevidenceなしに更新しない。過去成功を理由にcurrent failureをpassのままにしない。

## 12. Commit・push・draft Release運用

- Branch prefixは`codex/`を維持する。
- 延期中監査書をstageしない。YMM4 ZIP/binaryもstageしない。
- commit前に`git status --short`と`git diff --cached --check`を確認する。
- push後は対象HEADのGitHub Actionsが完了するまで待つ。
- `v0.1.0` draft releaseを更新するときはrelease ID `379098975`を先にAPIで確認する。
- 新しいdraftを重複作成しない。
- assetを差し替えたらlocal/hosted SHA-256とsizeを再照合する。
- draftのtarget commitを更新し、`draft=true`、`prerelease=true`を再確認する。
- ユーザーの別承認なしにpublishしない。
- Developer IDがないため、development DMGを署名・公証済みまたはrelease-readyと呼ばない。

確認例:

```sh
gh api repos/oriyu90/YMM4M/releases/379098975 \
  --jq '{tag_name,target_commitish,draft,prerelease,assets:[.assets[]|{name,size,digest}]}'
```

## 13. 完了済み作業を繰り返さない

- PROJECT001一般loader診断とAquesTalk1分離は完了済み。
- 未修正WineD3D/D3DMetal/DXMT baseline採取は完了済み。
- managed Metal view、D2D/DWrite、font fallback patchの根拠採取は完了済み。
- Finder `.ymmp` open、M: containmentは完了済み。
- Official YMM4 Lite 4.55.1.1 ZIP/exe hashの確定は完了済み。
- versioned install、atomic channel primitive、real ZIP contractは完了済み。
- v0.1.0 development build 4とdraft Release作成は完了済み。

新しい失敗・変更軸がない限り、上記を最初からやり直さない。既存evidenceを読み、変更範囲に必要な回帰だけを追加する。

## 14. Release-readyへ進むための未完gate

- Lite-supported voice workflowとTier A編集・メディア・再生の完了
- DND/clipboard、Windows reference、OS/hardware matrix
- Win32Service crashの機能影響
- long-duration soak、fault injection、crash recovery
- 完全なupdate/rollback UIとclean-machine recovery
- runtime source/component inventoryと配布方針
- Developer ID、必要entitlement、署名、公証、stapling、Gatekeeper評価
- 全gate完了後の最終license audit

Developer IDが利用不可の間は、最後の5項目のうち署名・公証系は明示的blockerである。それでも通常開発、修正、回帰、development DMG、draft Release更新は可能だが、公開releaseへ昇格してはならない。

## 15. 次回セッションの推奨開始アクション

1. 必須文書を読む。
2. `git status --short`、branch、HEAD、draft release API、最新CIを確認する。
3. `compatibility/features.yaml`と`STATUS.md`のcurrent failure/partial/untestedだけを抽出する。
4. P0のrollback UIまたはAppStorage migrationから一つを選び、失敗contractを先に追加する。
5. 最小修正を実装し、該当contract→全host gate→必要ならruntime/YMM4回帰の順で通す。
6. evidenceと全正本を同期する。
7. 延期監査書を除外してcommit/pushし、CI成功まで確認する。

判断に迷った場合は、互換性を広く推測するより、既存versionを壊さず明確に停止する方を選ぶ。
