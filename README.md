# YMM4M

Author: **Yuki_Orita**（折田悠希 / おりたゆうき） · License: MIT · <https://studio-rizi.pages.dev/projects/ymm4m/>

YMM4M is an unofficial compatibility project for YukkuriMovieMaker4.

YMM4M is not affiliated with or endorsed by the developer of
YukkuriMovieMaker4.

YukkuriMovieMaker4 itself is not part of the YMM4M project.

YMM4Mは、Apple Silicon Mac（macOS 26以降）上で公式YukkuriMovieMaker4（YMM4）を動かすための、非公式互換環境です。YMM4本体、Microsoft製ランタイム、Wine、DXMT、LLVM、フォント、CrossOverはこのリポジトリにもDMGにも含みません。

## 現在の状態

**v1.0.1（2026-09-11）**。EXTERNAL_ONLY方式の保守リリースです。配布DMGにはYMM4M独自のMITコード、bootstrap/stage/gateスクリプト、`bootstrap.lock.json`、Wine/DXMT用の4パッチ、8本のゲートfixture、互換カタログのみを含みます。Wine/DXMTはユーザーの同意後に、ユーザーのMacが固定URL（ミラー対応）から直接取得してhash検証し、ローカルでビルドします。各依存物の公開レベル判定は[LEGAL-AUDIT-v1.0.1.md](LEGAL-AUDIT-v1.0.1.md)で確定済みです（v1.0.0の判定を参照継承し、`UNKNOWN`なし）。

実装済み: ネイティブホスト、安全なYMM4 ZIP検査・導入、ローカルIPC、ネイティブエンコーダ基盤、診断情報収集。v1.0.1では診断文言を日英完全対応し、runtime URL到達性ゲートの修正、Rosetta実行プローブのfallback、検証対象外macOSでの注意表示を追加しました（[CHANGELOG.md](CHANGELOG.md)の1.0.1節）。分離した開発用DXMT/Wineランタイムでは、YMM4 v4.55.1.1 Liteのプロジェクト開閉、PNG・JPEG・GIF・WAV・MP3・H.264/AAC動画の読み込み、日本語テキストのプレビュー、FFmpeg動画書き出しまで確認しました。CrossOverを含まないWine 11.0＋ソースビルドDXMT候補でも8本の回帰テストとWPF software profileでのGUI表示を確認しています。IME直接確定不可の問題には、macOS側で変換を完了して確定文字だけを渡すバージョン限定の補助欄を実装しています。

**GPU**: YMM4のUI（WPF）は意図的にソフトウェア描画です。プレビューとエンコードの一部だけが開発用DXMTビルド経由でMetalを使います。詳細は[docs/GPU_EXPECTATIONS.md](docs/GPU_EXPECTATIONS.md)。

**このリリースで未完了（開示済みの制限。Wine/DXMTを同梱するリリースの前には必須）**: Developer ID署名・公証、Windows参照環境とのフレーム／音声比較、Tier Aの編集・再生の網羅、`Win32Service.exe`クラッシュの機能影響確定（[docs/WIN32SERVICE_INVESTIGATION.md](docs/WIN32SERVICE_INVESTIGATION.md)）、実セッションでのGPU Metalワーク計測、宣言する実機マトリクス。

正確な実測状態は[STATUS.md](STATUS.md)と[COMPATIBILITY.md](COMPATIBILITY.md)を参照してください。

## MacでYMM4を開く

DMG単体ではYMM4本体を起動できません。画面で同意して
`互換環境を一括インストール`を押し、ユーザーが入手した公式YMM4 ZIPと
メディア・プロジェクト用フォルダを選びます。Wine/DXMTの固定取得・hash検証・build、
WPF設定済みprefix、YMM4の検証済みコピー、M:割当、保存設定まで自動で完了します。
runtime、prefix、YMM4は旧versionを保持し、検証後だけ`current`を原子的に切り替えます。
不完全な前回セットアップは`Recovery`へ退避して再開でき、未知の更新は互換扱いせず安全に停止します。

現在はYMM4 4.55.1.1の通常版とLiteのZIP導入・起動に対応します。ZIPは自動削除されない場所に保存してから選び、再セットアップ用に保管してください。保存設定は次回起動に引き継ぎ、旧標準パスは安全に検証できる場合だけ`current`へ正規化します。

更新耐性の監査結果と残る制約は[Runtime・YMM4更新耐性の設計監査](docs/UPDATE_COMPATIBILITY_AUDIT.md)を参照してください。

詳しい導入、ad-hocアプリの扱い、現在の開発マシンで選ぶパス、`.ymmp` の
開き方、日本語入力補助は
[MacでYMM4を開く手順](docs/MAC_SETUP.md)を参照してください。

Wine/DXMTを同梱する将来のリリースに向けた全面監査・署名・公証の実行手順は[NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md](NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md)を参照してください。ライセンス判定は[LEGAL-AUDIT-v1.0.1.md](LEGAL-AUDIT-v1.0.1.md)です。

## 開発

必要条件:

- Apple Silicon Mac
- Swift 6.2以降
- Python 3.9以降
- Xcode（アプリの署名・配布時）

ローカル検証:

```bash
swift build
swift run YMM4MContractTests
python3 -m unittest discover -s tests/unit -p 'test_*.py'
python3 tools/inspect-system.py --output evidence/environment.json
```

YMM4 ZIPはコミットせず、次の検査コマンドでメタデータだけを保存します。

```bash
python3 tools/inspect-ymm4.py /path/to/official-YMM4.zip \
  --output evidence/ymm4-4.55.1.1-inventory.json
```

CrossOverを含まない開発候補は、公式Wine 11.0資源とパッチ済みWine/DXMTビルドを指定して、新規の空パスへだけ組み立てます。

固定sourceの取得からbuild、配置、prefix作成まで行う場合:

```bash
tools/bootstrap-wine-dxmt-runtime.sh --accept-third-party \
  --runtime "$HOME/Library/Application Support/YMM4M/Runtimes/versions/wine-11.0-dxmt-e55ad281-patchset5" \
  --prefix "$HOME/Library/Application Support/YMM4M/Prefixes/versions/wine-11.0-dxmt-e55ad281-patchset5-prefix-v2"
```

```bash
YMM4M_WINE_RESOURCES=/path/to/Wine\ Stable.app/Contents/Resources/wine \
YMM4M_WINE_BUILD=/path/to/patched-wine-build \
YMM4M_DXMT_BUILD=/path/to/patched-dxmt-build \
YMM4M_RUNTIME_STAGE=/new/path/to/runtime \
tools/stage-clean-wine-dxmt-runtime.sh
```

生成された `ymm4m-runtime.json` と主要ファイルのSHA-256はホスト側の固定値とも照合されます。起動時は `YMM4M_RUNTIME=/new/path/to/runtime` を指定し、任意のWineや外部から渡されたライブラリ検索パスは採用しません。

## ライセンス

YMM4M独自ソースはMIT Licenseです。第三者コンポーネントにはそれぞれのライセンスが適用されます。詳細は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)を参照してください。
