# Architecture and maintenance guide

最終更新: 2026-08-30

## 所有境界

| 領域 | 責務 | 変更時の必須確認 |
|---|---|---|
| `app/YMM4M/App` | ARM64 SwiftUI hostとユーザー操作 | UI build、手動操作、Developer IDなしの表示 |
| `app/YMM4M/Runtime` | runtime検証、bootstrap、Wine起動 | allowlist環境、hash、prefix安全性、contract test |
| `patches/` | 公開reproducerで裏付けた最小Wine/DXMT差分 | 対応evidence、upstream base、fixture regression |
| `runtime/bootstrap.lock.json` | network入力の固定値 | 一次配布元、commit、archive SHA-256、license |
| `compatibility/ymm4-releases.json` | 対応YMM4 ZIP/exe、必要runtime、保守familyの固定境界 | 公式archive、実測hash、両edition境界、回帰evidence |
| `compatibility/features.yaml` | 現在の機能判定の正本 | 新しい失敗を過去成功で上書きしない |
| `tools/` | build、stage、prefix、検証 | shell syntax、上書き拒否、秘密値非継承 |

## runtime pin更新手順

1. 更新理由と公開reproducer/evidenceを先に記録する。
2. upstream tag/commitとsubmodule commitを確定する。
3. HTTPS archiveを別の一時領域へ取得し、SHA-256とarchive rootを記録する。
4. license/COPYING/NOTICEと配布条件を確認する。DXMTをMITとして扱わない。
5. `runtime/bootstrap.lock.json` を更新する。
6. clean sourceへpatchが適用できることを確認する。
7. 新規build/runtime pathで再構築し、fixture、manifest、YMM4 matrixを再実行する。
   Wine PEは別の2つのbuild rootで全体SHA-256が一致することも確認する。
8. `runtime.lock.json`、`compatibility/features.yaml`、`STATUS.md`、evidenceを同じcandidateへ揃える。

hashだけの更新や可変URLへの置換は禁止する。既存runtimeへの上書きも禁止する。

runtimeとprefixはそれぞれ`versions/`へ新規作成し、全検証後に`current` symlinkを原子的に切り替える。prefixのbinding manifestにruntime profileとprefix schemaを記録し、起動時に組合せを再検証する。新profileは既存profileと同じdirectory名を再利用しない。

## YMM4更新手順

1. ユーザー提供の公式ZIPを隔離領域で取得し、ZIP全体とexeのSHA-256を記録する。
2. 現runtime profileで対象workflowを再検証し、evidenceを作る。
3. `compatibility/ymm4-releases.json`へrelease ID、archive hash、exe hash、classification、required runtime profileを追加する。
4. catalog validation、実ZIP contract、GUI起動を通す。
5. 未検証versionはknown-compatibleへ昇格しない。

同一保守familyの将来stable assetは、固定公式repositoryのasset name/size/SHA-256、
safe ZIP、AMD64 GUI PE、bundle内に固定した.NET/WPF境界がすべて一致した場合だけ
`maintenanceCandidate`として明示導入できる。公式receiptは配布物の真正性だけを示し、
互換性の判定をremote metadataへ委ねない。系列外、runtime境界変更、pre-release、offline
照合不能は既存`current`を変えず停止する。

YMM4は`YMM4/versions/<release-id>`へ導入し、成功後だけ`YMM4/current`を切り替える。
候補導入時は旧versionを`previous`に保持する。`user`はStandard/Lite別共有領域へ接続し、
version切替で設定を隠さない。競合する既存dataは自動mergeしない。YMM4 pluginやvoice engineは
本体hashと別の互換軸として扱う。

## UIと障害表示

標準利用者に必要なのは、自動setupへの同意、公式YMM4 ZIPの選択、設定確認、`YMM4をMacで開く`の順である。runtime/prefix pathと展開済みexe選択は詳細設定へ置く。download、hash、toolchain、build、prefix、ZIP検証のどの段階で止まったかを状態欄へ表示し、失敗を「互換性なし」と一括表示しない。

WPF、D3D11、D3D12、WebView2の障害は別issue・別evidenceとして扱う。WPF software profileはprefix構成であり、DXMT patchではない。

## リリース運用

- YMM4、Microsoft proprietary runtime/font、CrossOverをcommitまたはDMGへ入れない。
- Developer IDがない間はad-hoc development DMGだけを作り、署名・公証済みと表示しない。
- runtime source bootstrapが動いても、生成runtimeをrelease assetへ同梱してよいとは判断しない。
- GitHub releaseは要求どおりdraftまでとし、公開操作は別承認とする。
- final pre-release gateに到達するまで延期中の監査文書を開かない。

## 最小回帰セット

```bash
swift build
swift run YMM4MContractTests
python3 -m unittest discover -s tests/unit -p 'test_*.py'
python3 tools/validate-compatibility.py
sh -n tools/bootstrap-wine-dxmt-runtime.sh tools/create-prefix.sh \
  tools/configure-japanese-fonts.sh tools/setup-prefix-from-runtime.sh \
  tools/stage-clean-wine-dxmt-runtime.sh
git diff --check
```

実runtime変更時はこれに8 fixture、compute 100回、WPF GUI、YMM4の対象workflowを追加する。
