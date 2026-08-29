# Runtime・YMM4更新耐性の設計監査

最終更新: 2026-08-30

## 結論

更新後も無条件に動作することは保証しない。Wine/DXMT、WPF、YMM4はいずれも将来の未知の変更を含むため、YMM4Mは「既知の組合せだけを起動し、未知の組合せは既存環境を壊さず停止する」設計を採る。今回、runtime、prefix、YMM4をversion別に保持し、検証完了後だけ`current` symlinkを原子的に切り替えるよう修正した。

## 監査で見つかった問題と修正

| 以前の問題 | 影響 | 修正後 |
|---|---|---|
| runtimeとprefixの完成先が単一固定path | 更新途中の失敗や上書きで動作中環境を壊し得る | `versions/<profile>`へ新規作成し、検証後だけ`current`をatomic switch。旧versionを保持 |
| prefixがどのruntime向けか記録されない | 古いWPF設定と新runtimeの混在を検出できない | prefixに`ymm4m-runtime-binding.json`を保存し、runtime profileとprefix schemaを起動前検証 |
| YMM4対応hashがSwift実装に埋め込まれていた | 更新判断とコード変更が密結合 | `compatibility/ymm4-releases.json`を機械可読な対応カタログとしてbundle |
| ZIP導入処理がUIにつながっていなかった | 利用者が展開先やexeを理解して手動設定する必要 | `ZIPを選んで準備`で構造・容量・hashを検証し、version別領域へ導入 |
| 設定pathが過去の実体directoryを指し続ける | update後も旧versionを起動し得る | 標準設定はruntime、prefix、YMM4の各`current` channelを参照 |
| YMM4 archiveと展開後exeの対応が曖昧 | 改変・取り違えを見逃し得る | ZIP全体と展開後`YukkuriMovieMaker.exe`を個別にSHA-256検証 |

## 更新フロー

### Wine/DXMT runtime

1. URL、commit、archive hash、patch setをlockで固定する。
2. 既存versionとは別の`Runtimes/versions/<runtime-profile>`へbuild・stageする。
3. runtime manifestと全固定hashを検証する。
4. 対応する`Prefixes/versions/<runtime-profile>-prefix-v<schema>`を新規作成する。
5. WPF software profile、prefix-local font、binding manifestを検証する。
6. prefixとruntimeの`current` channelを切り替える。途中で片側だけ切り替わっても、次回setupがbinding不一致を検出して修復する。

既存の単一path配置は、明示的にsetupを実行した時だけversioned storeへ移行する。完成済みversionは上書き・削除しない。

### YMM4

1. ユーザーが公式ZIPを選択する。YMM4MはYMM4を代理取得しない。
2. archive容量、ZIP entry数、展開後容量、絶対path、`..`、symlink、暗号化、重複名、local/central header不一致を展開前に検査する。
3. 対応カタログにあるZIP hashだけを受理する。
4. 一時directoryへ展開し、exe hashと通常fileであることを確認する。
5. `YMM4/versions/<release-id>`へ配置し、metadataを書いてから`YMM4/current`を切り替える。
6. 起動時にもexe hash、release classification、required runtime profileを再検証する。

## 正常動作の意味

- 既知の組合せ: regression evidenceとhashが一致すれば起動できる。
- 未知のYMM4更新: 自動的に互換扱いせず停止する。検証後にcatalogとevidenceを更新する。
- 未知のruntime更新: profile ID、全binary hash、prefix schemaを更新し、回帰試験を通すまで停止する。
- 破損・途中更新: `current`の外にstageするため、既存versionを上書きしない。

これは「将来版が必ず動く」保証ではなく、「未検証版を誤って動かさず、更新失敗から既存版を守る」保証である。

## 残る制約

- runtime binaryの期待hashは安全上host実装にも固定している。runtime更新にはアプリ更新が必要。
- 対応catalogをネットから自動更新する署名付きtrust feedは未実装。単なる可変URLのJSONは採用しない。
- 保存済み旧versionを選ぶrollback UIは未実装。atomic channelと旧version保持という回復primitiveまでは実装済み。
- YMM4 plugin、voice engine、WebView2、Win32ServiceはYMM4本体ZIPのhashだけでは互換性を保証できない。
- runtime build toolchain自体はlock対象外。不足時は安全に停止する。
- Developer ID署名・公証がないため、v0.1.0 DMGはdevelopment評価用でありrelease-readyではない。

## 更新時の必須gate

runtime更新時はwarning-as-error build、contract/Python tests、8 fixture、compute 100回、WPF GUI、対象YMM4 workflowを行う。YMM4更新時は公式ZIP/exe hash、CLI/GUI、project open/save/reopen、import/export、IME workaround、既知plugin境界を別々に再検証し、`compatibility/features.yaml`、`STATUS.md`、evidenceを同じ候補へ揃える。
