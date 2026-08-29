# Architecture and maintenance guide

最終更新: 2026-08-30

## 所有境界

| 領域 | 責務 | 変更時の必須確認 |
|---|---|---|
| `app/YMM4M/App` | ARM64 SwiftUI hostとユーザー操作 | UI build、手動操作、Developer IDなしの表示 |
| `app/YMM4M/Runtime` | runtime検証、bootstrap、Wine起動 | allowlist環境、hash、prefix安全性、contract test |
| `patches/` | 公開reproducerで裏付けた最小Wine/DXMT差分 | 対応evidence、upstream base、fixture regression |
| `runtime/bootstrap.lock.json` | network入力の固定値 | 一次配布元、commit、archive SHA-256、license |
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

## UIと障害表示

標準利用者に必要なのは、自動setupへの同意、YMM4 exe選択、設定確認、起動の順である。runtime/prefix pathは詳細設定へ置く。download、hash、toolchain、build、prefixのどの段階で止まったかを状態欄へ表示し、失敗を「互換性なし」と一括表示しない。

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
