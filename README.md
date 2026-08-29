# YMM4M

YMM4M is an unofficial compatibility project for YukkuriMovieMaker4.

YMM4M is not affiliated with or endorsed by the developer of
YukkuriMovieMaker4.

YukkuriMovieMaker4 itself is not part of the YMM4M project.

YMM4Mは、Apple Silicon Mac上で公式YukkuriMovieMaker4（YMM4）を動かすための、開発中の非公式互換環境です。YMM4本体、Microsoft製ランタイム、Wine、DXMT、CrossOverはこのリポジトリに含みません。

## 現在の状態

**Development / pre-alpha**です。ネイティブホスト、安全なYMM4 ZIP検査・導入、ローカルIPC、ネイティブエンコーダ基盤、診断情報収集を実装しています。分離した開発用DXMT/Wineランタイムでは、YMM4 v4.55.1.1 Liteのプロジェクト開閉、PNG・JPEG・GIF・WAV・MP3・H.264/AAC動画の読み込み、日本語テキストのプレビュー、FFmpeg動画書き出しまで確認しました。CrossOverを含まないWine 11.0＋ソースビルドDXMT候補でも8本の回帰テストと、WPF software profileでのGUI表示を確認しています。YMM4の入力欄へ直接IME確定できない問題には、macOS側で変換を完了して確定文字だけを渡すバージョン限定の補助欄を実装し、IME操作と項目の追加・保存を確認しました。保存済み日本語Text/Image/Audioプロジェクトの再読込は現候補で3/3成功しました。以前失敗した対照はvanilla Liteに含まれないAquesTalk1を選択しており、任意プラグイン問題として分離済みです。ただし、残るTier A編集・再生・Windows比較、配布物の最終監査、署名、公証は未完了のため、まだリリースできません。

正確な実測状態は[STATUS.md](STATUS.md)と[COMPATIBILITY.md](COMPATIBILITY.md)を参照してください。配布用の署名・公証とrelease直前のライセンス監査は未実施です。

## MacでYMM4を開く

開発用DMG単体ではYMM4本体を起動できません。画面で同意するとWine/DXMTを
固定URLから取得・hash検証・buildし、WPF設定済み専用prefixまで自動作成します。
その後、ユーザーが入手した公式 `YukkuriMovieMaker.exe` を選択します。

詳しい導入、ad-hocアプリの扱い、現在の開発マシンで選ぶパス、`.ymmp` の
開き方、日本語入力補助は
[MacでYMM4を開く手順](docs/MAC_SETUP.md)を参照してください。

次回セッションの全面監査、バグ修正、署名・公証DMGまでの完全な実行手順は[NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md](NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md)を参照してください。

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
  --runtime "$HOME/Library/Application Support/YMM4M/Runtimes/ymm4m-wine-11.0-dxmt" \
  --prefix "$HOME/Library/Application Support/YMM4M/Prefixes/YMM4"
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
