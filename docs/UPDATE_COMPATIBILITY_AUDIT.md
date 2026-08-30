# Runtime・YMM4更新耐性の設計監査

最終更新: 2026-08-30

## 結論

更新後も無条件に動作することは保証しない。既知hashは従来どおり厳密に起動し、将来の同一4.55.1.x安定版だけは、公式assetのSHA-256と公開packageのruntime境界が一致した場合に限り`maintenanceCandidate`として試せる。既知互換版への自動昇格は行わない。runtime、prefix、YMM4をversion別に保持し、切替前のYMM4を`previous`へ残す。

## 監査で見つかった問題と修正

| 以前の問題 | 影響 | 修正後 |
|---|---|---|
| runtimeとprefixの完成先が単一固定path | 更新途中の失敗や上書きで動作中環境を壊し得る | `versions/<profile>`へ新規作成し、検証後だけ`current`をatomic switch。旧versionを保持 |
| prefixがどのruntime向けか記録されない | 古いWPF設定と新runtimeの混在を検出できない | prefixに`ymm4m-runtime-binding.json`を保存し、runtime profileとprefix schemaを起動前検証 |
| YMM4対応hashがSwift実装に埋め込まれていた | 更新判断とコード変更が密結合 | `compatibility/ymm4-releases.json`を機械可読な対応カタログとしてbundle |
| ZIP導入処理がUIにつながっていなかった | 利用者が展開先やexeを理解して手動設定する必要 | `ZIPを選んで準備`で構造・容量・hashを検証し、version別領域へ導入 |
| 設定pathが過去の実体directoryを指し続ける | update後も旧versionを起動し得る | 標準設定はruntime、prefix、YMM4の各`current` channelを参照 |
| YMM4 archiveと展開後exeの対応が曖昧 | 改変・取り違えを見逃し得る | ZIP全体と展開後`YukkuriMovieMaker.exe`を個別にSHA-256検証 |
| 完全hash一致だけでは小規模YMM4更新のたびにアプリ更新が必要 | 安全だが保守更新を全く試せない | 公式GitHub asset receiptと固定runtime境界を別々に検証し、同一系列だけを暫定候補にする |
| version別YMM4領域に`user`も分断される | 更新後に設定・ログ・backupが見えなくなる | Standard/Lite別の共有`user-data`を保持し、各versionから参照。旧Lite dataはcopy保全 |
| rollback primitiveだけでUIがない | 不具合時に利用者が戻せない | `前のYMM4へ戻す`で`current`/`previous`をatomicに切替 |

## 更新フロー

保存済み設定は次回起動時に再利用する。旧版アプリが標準管理領域の旧runtime、prefix、
YMM4 version実体を保存していた場合は、対応する`current`が実在するときだけ
チャネルパスへ正規化する。対象がない場合は実体を動かさずsetupを促し、任意custom pathと
環境変数は変更しない。

### Wine/DXMT runtime

1. URL、commit、archive hash、patch setをlockで固定する。
2. 既存versionとは別の`Runtimes/versions/<runtime-profile>`へbuild・stageする。
3. runtime manifestと全固定hashを検証する。
4. 対応する`Prefixes/versions/<runtime-profile>-prefix-v<schema>`を新規作成する。
5. WPF software profile、prefix-local font、binding manifestを検証する。
6. prefixとruntimeの`current` channelを切り替える。途中で片側だけ切り替わっても、次回setupがbinding不一致を検出して修復する。

既存の単一path配置は、明示的にsetupを実行した時だけversioned storeへ移行する。完成済みversionは上書き・削除しない。

### YMM4

公式ZIPは自動削除されない場所に保存してから選択する。YMM4Mは元ZIPを移動・変更・削除しない。

1. ユーザーが公式ZIPを選択する。YMM4MはYMM4を代理取得しない。
2. archive容量、ZIP entry数、展開後容量、絶対path、`..`、symlink、暗号化、重複名、local/central header不一致を展開前に検査する。
3. 既知ZIPは対応カタログのhashで受理する。未知ZIPは固定された公式GitHub repositoryのstable release asset名・size・SHA-256を照合する。
4. 未知版は同一4.55.1.x、4.55.1.1より新しい版、Standard/Lite、固定.NET/WPF境界の全条件を満たす場合だけ暫定候補にする。
5. 一時directoryへ展開し、AMD64 Windows GUI PEと必須runtime file hashを確認する。
6. 明示確認後、旧`current`を`previous`へ保持し、候補を`current`へ切り替える。
7. edition別共有`user-data`を各versionの`user`へ接続する。競合dataは自動mergeしない。
8. 起動時にもexe hash、install receipt、runtime境界、release classification、required runtime profileを再検証する。

## 正常動作の意味

- 既知の組合せ: regression evidenceとhashが一致すれば起動できる。
- 同一保守系列の公式YMM4更新: 条件一致時だけ暫定候補として明示導入できる。動作互換とは表示しない。
- 系列外・runtime境界変更・pre-release・公式照合不能: 大型または未検証更新として`current`を変えず停止する。
- 未知のruntime更新: profile ID、全binary hash、prefix schemaを更新し、回帰試験を通すまで停止する。
- 破損・途中更新: `current`の外にstageするため、既存versionを上書きしない。

これは「将来版が必ず動く」保証ではなく、「未検証版を誤って動かさず、更新失敗から既存版を守る」保証である。

## 残る制約

- runtime binaryの期待hashは安全上host実装にも固定している。runtime更新にはアプリ更新が必要。
- YMM4M独自のremote互換判定は受信しない。公式APIはasset identityにだけ使い、互換familyとruntime hashはbundle内固定policyを使う。
- rollbackは直前のactive version 1件を手動で戻す。crash-loopの自動検知・自動rollbackは未実装。
- YMM4固有のversion別設定migrationは書き換えない。edition別user rootを保持して公式挙動から見えるようにする範囲に限定する。
- YMM4 plugin、voice engine、WebView2、Win32ServiceはYMM4本体ZIPのhashだけでは互換性を保証できない。
- runtime build toolchain自体はlock対象外。不足時は安全に停止する。
- Developer ID署名・公証がないため、v0.1.0 DMGはdevelopment評価用でありrelease-readyではない。

## 更新時の必須gate

runtime更新時はwarning-as-error build、contract/Python tests、8 fixture、compute 100回、WPF GUI、対象YMM4 workflowを行う。YMM4更新時は公式ZIP/exe hash、CLI/GUI、project open/save/reopen、import/export、IME workaround、既知plugin境界を別々に再検証し、`compatibility/features.yaml`、`STATUS.md`、evidenceを同じ候補へ揃える。
