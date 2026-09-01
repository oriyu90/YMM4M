# Runtime bootstrap design

最終更新: 2026-08-31

## 目的と境界

YMM4Mの「互換環境を一括インストール」は、YMM4用のclean Wine/DXMT runtime、専用prefix、ユーザーが選んだ公式YMM4 ZIPの管理用コピー、メディアフォルダのM:割当をまとめて構築する。YMM4MはYMM4を取得せず、元ZIPやユーザーprojectを移動・削除・変更しない。Microsoft runtime/fontとCrossOverも取得しない。公開配布用runtimeを作る処理ではなく、明示的な同意に基づくローカル開発用bootstrapである。

## 信頼モデル

- 入力のURL、commit、SHA-256、archive rootは `runtime/bootstrap.lock.json` に固定する。
- 通信はHTTPSだけを許可し、download完了後のSHA-256不一致は配置前に停止する。
- archive memberに絶対pathまたは `..` があれば展開を拒否する。
- Wine 11.0 source、Gcenx macOS Wine 11.0_1 base、FreeType 2.14.3 source headers、DXMT source、DXMTが固定するNVAPIとDirectX headers、Wine内の日本語fallbackに使うNoto Sans CJK JP、DXMT buildに使うupstream LLVM 15.0.7 x86_64 release（build toolのみ、runtimeへは同梱しない）だけを取得する。
- CrossOverを名前に含む入力・出力は拒否する。
- 既存runtimeを上書きしない。途中生成物はruntimeとは別のcache/source/build領域に置く。
- 最終runtimeは既存の `stage-clean-wine-dxmt-runtime.sh` で組み立て、`ymm4m-runtime.json` を生成する。アプリ起動時にも全固定hashを再検証する。

## 処理の流れ

1. UIで第三者softwareのdownload/buildへの同意を得る。
2. Rosetta 2、build command、MinGW GCC versionをpreflightする。x86_64 LLVM 15 toolchainが無ければ固定releaseから取得・SHA-256検証して展開する。
3. 固定archiveをcacheへdownloadしてSHA-256を検証する。
4. Wine/DXMT sourceを安全に展開し、証拠に基づく4 patchだけを適用する。
5. Gcenx baseのFreeType libraryと固定source headersを使い、Wineをx86_64 macOS向けにbuildする。source/build pathは一定の仮想pathへmapし、PE binaryを再現可能にする。
6. DXMTの固定submodule sourceを配置し、DXMTをbuildする。
7. macOS Wine baseへsource-built成果物だけをstageする。
8. runtime manifestを検証し、専用prefixを `wineboot` で作る。
9. `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1` を設定する。
10. 固定hashのNoto Sans CJK Regular TTCからJP Regular faceを `hb-subset` で抽出してprefix内だけへ配置し、Wine font replacementを設定する。TTCを直接Wineへ渡さない。

標準配置はversion storeとactive channelに分ける。

```text
~/Library/Application Support/YMM4M/Runtimes/versions/wine-11.0-dxmt-e55ad281-patchset5
~/Library/Application Support/YMM4M/Runtimes/current
~/Library/Application Support/YMM4M/Prefixes/versions/wine-11.0-dxmt-e55ad281-patchset5-prefix-v2
~/Library/Application Support/YMM4M/Prefixes/current
```

download cacheは `~/Library/Application Support/YMM4M/Downloads`、破棄可能なsource/build treeは空白を含まない `~/Library/Caches/YMM4M` に置き、再実行時に再利用する。Wineの`CROSSCFLAGS`は空白を含むpathを正しく保持できないため、custom source/build rootに空白があればpreflightで拒否する。完成済みruntimeはmanifestとbinary hashが一致する場合だけ再利用する。prefixにはruntime profileとprefix schemaをbinding manifestとして保存する。runtimeとprefixの両方が完成・検証されてから`current` channelをatomicに切り替え、旧versionは削除しない。途中で片側だけ切り替わった場合はbinding不一致で起動を拒否し、次のsetupが同じ完成versionへchannelを修復する。

Wineの `winemac.so` は同じloadable code/dataでもlink時の `LC_UUID` と `__LINKEDIT` local symbol tableがbuildごとに変わる。これらを削除すると機能回帰が観測されたため、binaryは加工しない。manifestのfull-file SHA-256で配置後の改変を検出し、host側では `LC_UUID` をzero化して `__LINKEDIT` より前だけをhashした固定loadable-image SHA-256も照合する。

WineのPE moduleは `__FILE__` とdebug情報にbuild pathを含むため、`-ffile-prefix-map`でsource/build rootを固定名へ置き換える。異なる2つのbuild rootで `d2d1.dll` / `dwrite.dll` のbyte identityを確認し、hostは引き続きfull-file hashを検証する。

MinGWのmajor versionが変わると、同じ固定source・patch・path mapでもPE出力は一致しない。hostは従来の監査済みvariantと、GCC 16.2で本機上に再生したvariantの完全なhash setだけを別々に許可する。variant間のhash混在、未知のmanifest、対応しない `winemac.so` loadable-image hashは拒否する。

## 依存関係と失敗時の扱い

bootstrapはRosetta 2、Xcode command line tools、GNU Bison 3以上、Meson、Ninja、CMake、MinGW cross compilerを必要とする。prefixまで作る場合は `hb-subset` も必要とする。これらは取得lock対象外で、不足時は導入コマンドを表示してdownload前に停止する。x86_64 LLVM 15はDXMT buildのためのbuild toolであり、`YMM4M_LLVM15_ROOT`（既定 `~/Library/Application Support/YMM4M/Toolchains/llvm15-x86_64`）に無ければ `runtime/bootstrap.lock.json` の固定upstream releaseからSHA-256検証付きで取得・展開する。取得物はruntimeへstageも再配布もしない。MinGW GCCは完全なhash setとfixtureを検証済みの15.2.0または16.2.0だけを許可する。他versionはアプリ側の `RosettaWineBackend.verifiedRuntimeVariants` と一致するPEを生成しないため、未知runtimeをstageする前に理由と `brew pin` の案内を表示して停止する。Rosettaはpreflightで存在のみ確認し、恒久的依存設定や管理者権限取得、SIP/Gatekeeper全体無効化は行わない。

download/build失敗時に完成先runtimeは作られない。再実行時、固定された管理用version先に不完全なruntime・prefix・YMM4がある場合は削除や上書きをせず、各storeの`Recovery`へ退避してから再構築する。壊れた管理用`current`も同様だが、store外を指すsymlinkは改変せず停止する。検証済みのactive/old versionとuser projectは削除・上書きしない。再実行は検証済みdownload cacheと完成済みbuild artifactを再利用する。

新規prefix作成中に任意device初期化がWine例外を起こしても、対話デバッガがUI背後で無限待機しないようsetup中の`winedbg.exe`だけを無効化する。Wineの終了コード、registry、WPF profile、font、prefix marker、binding検証は省略しない。成功・失敗の両方でprefix専用wineserverを停止し、子プロセスがlog pipeを保持し続けないようにする。

UIはphase markerを逐次表示し、サブプロセスの全出力を `~/Library/Application Support/YMM4M/Logs/automatic-setup.log` へ保存する。downloadはconnect 20秒、1 KiB/s未満が60秒続いた場合にtimeoutし、transient errorを3回まで再試行する。

## ライセンス上の位置づけ

WineとDXMTはLGPL-2.1-or-laterで、FreeTypeはFTLまたはGPL-2.0-onlyのdual license、NVAPI library filesはMIT、mingw-directx-headersは複数notice、Noto Sans CJK JPはSIL OFL 1.1を含む。Gcenx archiveはWine macOS packageの取得元であり、YMM4Mが権利を取得したことを意味しない。本機上でsource/fontを取得・build/configureする機能の実装と、生成binaryやfontの公衆配布可否は別判断である。公開releaseへruntimeを含める前には、延期中の最終release auditを実行し、対応source、patch、notice、再リンク条件を確定する。

## 再現テスト

ネットワークやbuildを行わない計画確認:

```bash
tools/bootstrap-wine-dxmt-runtime.sh --accept-third-party --plan \
  --runtime /tmp/ymm4m-runtime-plan --prefix /tmp/ymm4m-prefix-plan
```

実buildは必ず新規のruntime pathで行う。成功後は `swift run YMM4MContractTests` と `RosettaWineBackend.validateCleanRuntime` を通す。
