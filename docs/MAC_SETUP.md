# MacでYMM4を開く手順

## 最初に知っておくこと

YMM4M **v1.0.0**（EXTERNAL_ONLY）です。YMM4本体はユーザーが公式配布物を
用意します。画面の確認項目へ同意して「互換環境を一括インストール」を押し、
公式YMM4 ZIPとメディア・プロジェクト用フォルダを選ぶと、その他は自動で作成されます。

DMGにはYMM4M独自コード（MIT）とbootstrap/patch/fixture/カタログだけを含みます。
Wine/DXMT/フォント/LLVMはユーザーのMacが固定URLから直接取得します。ad-hoc署名・
未公証のため、初回起動はAppleの「このまま開く」を使ってください（Gatekeeper全体
無効化はしないこと）。GPUについては：YMM4のUIはソフトウェア描画、プレビューと
エンコードの一部だけがMetalを使います（`docs/GPU_EXPECTATIONS.md`）。

1. 自動作成する検証済みWine/DXMT互換ランタイムと専用prefix
2. 選んだ公式ZIPから専用領域へコピーするYMM4
3. `.ymmp` と素材を置くメディア・プロジェクト用フォルダ

YMM4、Wine、DXMT、CrossOver、Microsoft runtime/fontはDMGに含まれません。
Wine/DXMTは固定URLから取得してhash検証後にこのMacでbuildします。YMM4、
Microsoft runtime/font、CrossOverを自動取得することはありません。

## 1. DMGからYMM4Mを入れる

1. `YMM4M-1.0.0-arm64.dmg` を開きます。
2. `YMM4M.app` を `Applications` へドラッグします。
3. ApplicationsのYMM4Mを開きます。

この開発版はDeveloper ID署名・公証がありません。macOSが起動を拒否した
場合は、DMGのSHA-256を確認したうえで、Appleが案内するアプリ単位の
「このまま開く／Open Anyway」を使用してください。GatekeeperやSIPを全体で
無効化しないでください。

Apple公式: <https://support.apple.com/102445>

## 2. 互換環境を一括インストールする

先に、Rosetta 2 とHomebrewのbuild toolを用意します（初回のみ）。

```bash
softwareupdate --install-rosetta --agree-to-license
xcode-select --install
brew bundle --file=Brewfile   # meson ninja cmake mingw-w64 bison harfbuzz
```

Homebrew自体が無い場合は先に https://brew.sh の手順で導入してください。
`Brewfile` はYMM4Mのリポジトリ直下と、配布DMG内の
`YMM4M.app/Contents/Resources/RuntimeBootstrap/Brewfile` に入っています。
不足があるMacでは、セットアップ開始時に状態欄へ不足項目と使える
`brew bundle` コマンドをまとめて表示し、download前に停止します。

Xcode command line tools（`xcode-select --install`）も必要です。x86_64 LLVM 15 は
固定URLからYMM4Mが自動取得・SHA-256検証するため、手動導入は不要です（build tool
としてのみ使用し、runtimeには同梱しません）。

1. 公式YMM4 4.55.1.1の通常版またはLiteのZIPを、自動削除されない場所へ保存します。
2. 第三者softwareの取得・buildへの同意項目を確認して有効にします。
3. `互換環境を一括インストール` を押します。
4. 保管した公式YMM4 ZIPを選びます。元ZIPは移動・変更・削除されません。
5. YMM4で素材と`.ymmp`を管理するフォルダを選びます。選択パネル内で新規作成できます。
6. download、Wine/DXMT build、runtime/prefix作成、YMM4検証・コピー、M:割当、最終検証が終わるまで待ちます。

状態欄に `[download]`、`[prepare]`、`[build]`、`[stage]`、`[prefix]`、
`[gate]` の順で現在の段階が表示されます。長いdownloadやbuildの途中でも
約2分ごとに進行中である旨が出るため、そのままお待ちください。部分的な
runtimeを起動に使わないため、download/build中は
`Runtimes/current` がまだ無く、runtime保存先が空でも正常です。`[stage]` 後の
manifest・binary hash検証とprefix作成が成功したときだけ `current` へ
切り替えます。失敗時の詳細は次に保存されます。

```text
~/Library/Application Support/YMM4M/Logs/automatic-setup.log
```

空の状態だけでなく、中断したruntime・prefix・YMM4展開先や壊れた管理用`current`が残っていても同じボタンから再開できます。
不完全な対象は削除せず、各管理storeの`Recovery`へ退避します。検証済みの現在版と旧versionは保持し、新しい一式が完了するまで起動先を変更しません。
アプリの保存設定も、runtime、prefix、YMM4、M:割当の全検査が成功した後にだけ更新します。

標準保存先は `~/Library/Application Support/YMM4M` 配下です。ビルド前提が不足している
場合は、状態欄に**不足項目をまとめて**表示し、使える `brew bundle` コマンドと
`xcode-select --install` の案内を出してdownload前に停止します。空き容量は
download前に検査し、約10 GB未満（prefixのみの再作成時は約2 GB未満）では
何も取得せず停止します。x86_64 LLVM 15
は不足時に固定URL（ミラー対応）から自動取得します。空き容量は約10 GB以上（LLVM
toolchainの展開分を含む）を確保してください。ホームフォルダ名に空白が
含まれるMacでは、build用の一時領域を自動で空白の無い場所へ切り替えます。
MinGW GCCの厳密なpinは廃止しました。major 13未満は即停止、15〜18以外は警告のみで、
最終的な受け入れはstage後の8-fixture＋compute100ゲート（`RosettaWineBackend` schema 2）
の通過で判定します。ゲートに通らなければ`current`へ切り替えず失敗で停止します。

ログは既定で最小（`WINEDEBUG=-all`）です。詳細トレースが必要なときだけ
`YMM4M_WINEDEBUG` を設定してください。

取得済みarchiveは `Application Support/YMM4M/Downloads`、再作成可能なsource/build
中間成果物は `~/Library/Caches/YMM4M` へ分けて保存します。固定取得元とhash、設計上の境界は `runtime/bootstrap.lock.json` と
`docs/RUNTIME_BOOTSTRAP_DESIGN.md` を参照してください。

## 3. 個別セットアップ（開発者向け）

通常利用ではこの節の手動指定は不要です。「個別セットアップ・開発者向け詳細設定」を開いた場合だけ、各パスを手動指定できます。隠しフォルダを直接開く場合は、選択
パネルで `Command + Shift + G` を押してパスを入力できます。

互換ランタイムと専用prefixの2つは、**空のフォルダを指定してから「互換環境を一括インストール」を押しても構いません**。その場合、指定した各フォルダ配下に標準と同じ
`versions/<profile>` と `current` を作成し、runtime・prefix・YMM4コピー・M:割当・最終検証・設定保存まで自動で完了します。旧versionと`current`のatomic切替も標準の場所と同じ扱いです。2つは別々のフォルダにしてください。ホームフォルダやfilesystem rootは指定できません。環境変数 `YMM4M_RUNTIME` / `YMM4M_WINE` / `YMM4M_PREFIX` が設定されている場合は、それらが優先され、この指定は無視されます。

### 互換ランタイム

自動セットアップ成功後は選択済みパス（既定は標準の場所）が自動設定されるため、通常はここを手動で変更しません。
既存の検証済みruntimeを使う場合は `ymm4m-runtime.json` と `bin/wine` が入っているフォルダを、
一括インストールに作成させる場合は空のフォルダを選びます。
既定で作成・使用される標準パス:

```text
~/Library/Application Support/YMM4M/Runtimes/current
```

任意のWineやCrossOverのフォルダは使用できません。YMM4Mはmanifestと各
binaryのSHA-256が検証済み構成と一致するか確認します。

### 専用Wine prefix

こちらも自動セットアップ後は通常、手動選択不要です。
WPF software profile適用済みの準備済みprefix、または一括インストールに作成させる空のフォルダを、
互換ランタイムとは別の場所に選びます。
既定で作成・使用される標準パス:

```text
~/Library/Application Support/YMM4M/Prefixes/current
```

ホームフォルダやfilesystem rootはprefixとして拒否されます。既存の別Wine
環境を流用しないでください。

### YMM4本体

現在は公式YMM4 4.55.1.1の通常版とLiteの両方を選択できます。先にZIPをダウンロードフォルダなど、macOSや他のアプリが自動削除しない場所へ保存してください。再セットアップに備え、ZIPは保管しておくことを推奨します。YMM4Mは選んだ元のZIPを移動・変更・削除しません。

公式YMM4 Lite ZIPをユーザー自身で入手し、`ZIPを選んで準備`を押してZIPを選びます。YMM4Mがarchiveと展開後exeのhash、危険なentry、容量を検証し、次へ導入します。

```text
~/Library/Application Support/YMM4M/YMM4/versions/<release-id>/YukkuriMovieMaker.exe
~/Library/Application Support/YMM4M/YMM4/current/YukkuriMovieMaker.exe
```

4.55.1.1より新しい同一4.55.1.xの公式安定版は、公式GitHub assetの名前・サイズ・SHA-256と、検証済み.NET/WPF境界が一致する場合だけ「保守更新候補」として確認画面を出します。これは既知互換の保証ではありません。系列外やruntime境界が変わった版は大型更新として導入を拒否します。候補に問題があれば`前のYMM4へ戻す`で直前版へ切り戻せます。YMM4本体をDMGへコピーしないでください。展開済みexeの手動選択は開発者向け詳細設定です。

通常版4.55.1.1もZIP導入・CLI・GUI起動まで検証済みです。編集・メディアの詳細な回帰範囲はまだLite中心です。YMM4Mのruntime、prefix、YMM4、ZIP、プロジェクト用フォルダの選択は次回起動時にも引き継がれます。旧標準管理パスは検証可能な`current`がある場合だけ正規化し、任意のカスタムパスは自動変更しません。

管理されたYMM4の`user` dataは通常版とLiteを分けて共有保存するため、YMM4のversionを切り替えても同じeditionの設定・ログ・backup rootは保持されます。YMM4独自のversion別設定変換はYMM4側の動作に任せ、YMM4Mは設定JSONを書き換えません。

## 4. YMM4を起動する

1. `設定を確認` を押します。
2. 「設定OK」と表示されたことを確認します。
3. `2. YMM4をMacで開く` を押します。
4. YMM4のウィンドウが表示されるまで待ちます。

設定確認では、Rosetta、runtime manifest/binary hash、prefixの安全性とWPF
profile、YMM4 executable hashを検査します。検査を迂回して起動しないで
ください。

## 5. 既存の.ymmpを開く

1. `.ymmp` と参照素材を、専用のプロジェクト用フォルダ内に置きます。
2. YMM4Mの手順4で、そのフォルダを選びます。
3. `プロジェクトを選んで開く` を押し、フォルダ内の `.ymmp` を選びます。

選択したフォルダはWine側の `M:` ドライブになります。フォルダ外のprojectは
安全のため拒否されます。元projectを黙って移動・上書きすることはありません。
重要なprojectではなく、必ず分離したcopyから試してください。

Finderで `.ymmp` をYMM4Mへ「このアプリケーションで開く」方法も使えますが、
先にYMM4M内の手順1〜4を完了しておく必要があります。

## 6. 日本語を入力する

YMM4の台詞欄は、現在macOSの日本語IMEから直接確定できません。YMM4M下部の
「日本語入力補助」で変換を完了し、確定した文字だけをYMM4へ送ります。

- YMM4を先に起動します。
- YMM4Mの補助欄で日本語を変換・確定します。
- `確定した文字をYMM4の台詞欄へ送る` を押します。
- YMM4の「追加」は自動では押されません。

この機能はYMM4 Lite 4.55.1.1と、検証済みhelperが設定された開発環境に限定
されます。

## 現在の制限

- Developer ID署名・公証なし。Gatekeeperの通常配布gateには不合格です。
- build toolchainの自動取得は未実装です。不足時は手動導入が必要です。
- Win32Service crashの機能影響は未特定です。
- VoiceItem、可聴再生、effects、drag-and-drop、clipboard、Windows reference、
  長時間stability/recoveryは未完了です。
- release-readyなDMGではありません。

正確な現在状態は `STATUS.md` と `compatibility/features.yaml` を参照してください。
