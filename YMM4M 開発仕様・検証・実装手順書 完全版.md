# YMM4M 開発仕様・検証・実装手順書 完全版

**文書版:** 1.0  
**基準日:** 2026-08-24  
**プロジェクト名:** YMM4M  
**著作者:** Yuki_Orita  
**対象:** Apple Silicon Mac  
**開発環境前提:** `gh` 認証済み  
**YMM4基準版:** v4.55.1.1  
**YMM4M独自コードの予定ライセンス:** MIT License  
**開発方式:** Wine互換ランタイム + macOSネイティブホスト + 必要に応じたYMM4公式プラグインAPIによるブリッジ

---

# 1. プロジェクトの最終目的

YMM4Mは、Windows版YukkuriMovieMaker4（以下YMM4）をApple Silicon Mac上で、Windows仮想マシンなしに実用可能な状態で動作させるための非公式互換環境である。

YMM4自体を書き直さない。

Windowsそのものをエミュレートしない。

基本構成は、

```text
macOS native
┌─────────────────────────────┐
│ YMM4M.app                   │
│ ARM64 Swift / AppKit        │
│                             │
│ Launcher                    │
│ Runtime Manager             │
│ File Integration            │
│ Diagnostics                 │
│ Native Helper / Encoder     │
└──────────────┬──────────────┘
               │
               │ launch / IPC
               ▼
┌─────────────────────────────┐
│ YMM4M Windows Runtime       │
│                             │
│ Wine                        │
│ Windows .NET 10 Desktop     │
│ WPF                         │
│ Win32 / COM / DirectWrite   │
│ Direct3D / Direct2D         │
└──────────────┬──────────────┘
               │
               ▼
       YukkuriMovieMaker.exe
```

を基本とする。

ただし動画出力などWineだけでは不利な機能については、

```text
YMM4
 ↓
YMM4MBridge.dll
 ↓
安全なIPC
 ↓
YMM4M Native Helper
 ↓
FFmpeg / VideoToolbox / macOS API
```

というハイブリッド経路を使用できる設計にする。

---

# 2. 最初に理解すべき結論

## 2.1 YMM4の基本編集機能をMacへ持ってくることは技術的に十分狙える

2026年8月時点の調査では、

- 起動
- WPF UI
- タイムライン
- テキスト
- 画像
- 音声
- 一般的な動画
- 基本的な映像エフェクト
- プレビュー
- プロジェクト保存
- 動画出力

について、Wine系互換環境と必要な回避策を組み合わせる方式に技術的成立性がある。

ただし、現時点で「YMM4 v4.55.1.1の全機能がMac上で正常動作する」と確認されたわけではない。

必ず実機試験によって確認すること。

---

# 3. 100% Windows互換を目標にしてはいけない

YMM4は現在かなり大規模なWindowsアプリケーションである。

公式配布ページでは、少なくとも以下のWindows依存技術が確認できる。

- WPF
- Win32
- DirectWrite
- Direct2D
- Direct3D 9/11/12関連
- ComputeSharp
- Vortice.Windows
- DirectML
- WebView2
- FFmpeg
- Media Foundation系機能
- VST3
- OpenFX
- Windows音声合成ソフト連携

ComputeSharpはDX12・D2D1・HLSLを利用するGPU計算ライブラリであり、Vortice.WindowsにはD3D12、D3D11、D2D1、D3D9、XAudio等へのバインディングが含まれている。現行YMM4にはWebView2やDirectMLも含まれている。

さらにv4.55.0.0ではOpenFX、VST3、数多くの新しい映像処理が追加された。

したがってプロジェクトの成功条件を、

> Windows版YMM4全機能100%互換

としてはいけない。

---

# 4. サポートレベルを定義する

## Tier A — Core

v1.0までに必須。

- YMM4起動
- スプラッシュ
- メインUI
- 日本語UI
- 日本語IME
- マウス
- キーボードショートカット
- タイムライン
- テキストアイテム
- 画像アイテム
- WAV/MP3等音声
- 標準的なMP4動画
- 基本図形
- 基本アニメーション
- 基本映像エフェクト
- 基本音声エフェクト
- プレビュー
- 音声再生
- プロジェクト保存
- プロジェクト再読込
- コピー・貼り付け
- ドラッグ&ドロップ
- 一般的なFFmpeg動画読み込み
- 動画出力

Tier Aが安定して初めてYMM4Mを実用品とみなす。

---

## Tier B — Extended

v1.xで対応を目指す。

- クラウド型TTS
- VOICEVOX等localhost型音声エンジン
- 録音
- 文字起こし
- WebView2を利用する機能
- 多数の標準映像エフェクト
- 一般的なYMM4管理プラグイン
- 一部VST3
- 一部OpenFX
- Appleハードウェア動画エンコード

---

## Tier C — Experimental

正常動作を保証しない。

- D3D12依存エフェクト
- DirectML GPU推論
- Media Foundationハードウェアデコード
- Media Foundationハードウェアエンコード
- Windows COM依存音声合成
- SAPI
- A.I.VOICE等Windowsアプリ連携
- CeVIO等Windowsアプリ連携
- DRM/ライセンス管理を含むVST3
- GPU依存OpenFX
- 複雑なサードパーティプラグイン

---

## Tier D — Unsupported

原理的または現実的理由で初期サポートしない。

例:

- NVIDIA CUDA必須
- NVENC必須
- NVIDIA専用YMM4プラグイン
- Windowsカーネルドライバ必須
- Windows専用ハードウェアドングル
- macOSネイティブVST3をWindows版YMM4プロセスへ直接ロード
- macOSネイティブOpenFXをWindows版YMM4プロセスへ直接ロード

Apple SiliconにはNVIDIA GPUがないため、NVENC/CUDA専用機能を「Wine修正で解決する」と考えてはいけない。

---

# 5. 2026年8月24日時点のYMM4

公式更新履歴上の最新バージョンは、

```text
YukkuriMovieMaker v4.55.1.1
```

である。

公式サイトはMacについて明確に「動作しません」としている。

したがってYMM4Mは完全に非公式の互換プロジェクトとして扱う。

READMEに必ず、

```text
YMM4M is an unofficial compatibility project for YukkuriMovieMaker4.

YMM4M is not affiliated with or endorsed by the developer of
YukkuriMovieMaker4.

YukkuriMovieMaker4 itself is not part of the YMM4M project.
```

と同等の文言を入れる。

---

# 6. .NET仕様

YMM4公式ページには現在も`.NET Framework 4.7.2以上`という古い動作環境表記が残っているが、これを現在の内部構成判断に利用してはいけない。

YMM4はv4.47.0.0で.NET 10へ移行した。

公式プラグインサンプルも現在、

```xml
<TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>
<UseWPF>true</UseWPF>
```

である。

2026年8月24日時点の.NET 10最新パッチは、

```text
.NET 10.0.11
SDK 10.0.400
Windows Desktop Runtime 10.0.11
```

で、2026年8月11日に公開されている。Desktop RuntimeはWindows向けのみである。

ただし、

**YMM4Mが勝手に.NET Desktop Runtime 10.0.11をインストールしてはいけない。**

まず現在のYMM4 ZIPを解析する。

self-containedなら同梱ランタイムを使う。

framework-dependentの場合のみ、`runtimeconfig.json`が要求するWindows Desktop Runtimeを導入する。

---

# 7. 現時点で公開情報だけでは確定できないこと

次は推測禁止。

- `YukkuriMovieMaker.exe`の現在のPE Machine
- AMD64固定か
- ARM64/ARM64ECコンポーネントの有無
- self-containedかframework-dependentか
- 同梱coreclrの有無
- ネイティブDLLのアーキテクチャ
- 実際にYMM4起動時に使用するD3D API
- 各エフェクトがD3D11かD3D12か
- WebView2を利用する具体的画面
- DirectMLを利用する具体的機能
- Media Foundationが必須になる機能
- `IVideoFileWriter.WriteVideo(byte[])`の正確なピクセル形式
- `WriteAudio(float[])`のチャンネル・サンプル配置詳細

これらについてプロプライエタリなYMM4本体を逆コンパイルして推測するのではなく、

1. 公開API
2. ファイルメタデータ
3. PEヘッダ
4. runtimeconfig/deps
5. インポートテーブル
6. Wine実行ログ
7. Windows実機とのブラックボックス比較

で確定する。

YMM4本体ILの本格的な逆コンパイルは、ライセンス上の確認を取らずに行わない。

---

# 8. 前回設計からの重要修正点

## 修正1 — Wine 11.16を「採用版」に固定しない

2026年8月21日時点の最新開発版はWine 11.16である。Stableは11.0。

しかし最新版だからYMM4との互換性が高いとは限らない。

初期評価では必ず、

```text
Wine 11.0 Stable
Wine 11.16 Development
CrossOver 26.3.0
```

を比較する。

CrossOver 26.3.0が2026年7月21日時点の現行安定版である。

最も互換性の高いWine revisionを実測によってRuntime Candidateとする。

---

# 9. 修正2 — グラフィックスを一つの「Renderer」で扱わない

旧案:

```text
WineD3D
DXMT
D3DMetal
```

から一つを選択。

これは不十分。

YMM4ではグラフィックスを少なくとも4系統に分離する。

```text
Graphics
│
├── UIRenderPlane
│   └── WPF / D3D9
│
├── EditRenderPlane
│   └── D2D / D3D11
│
├── ComputePlane
│   └── D3D12 / ComputeSharp / DirectML
│
└── WebRenderPlane
    └── WebView2 / Chromium / DirectComposition
```

それぞれ別問題として扱う。

---

# 10. UIRenderPlane — WPF

最大の初期リスク。

2026年8月現在もWineにはWPFの黒画面・描画破損問題が存在する。

Wine 11.14をmacOS 26.5.2、Apple M2、Rosettaで動かした再現結果では、WPFが利用するD3D9追加swapchain経路で問題が発生している。

同テストではOpenGL rendererで失敗し、Vulkan rendererでは成功した結果も報告されている。

`DisableHWAcceleration`でWPFソフトウェア描画にすると回避できる理由も確認されている。

したがって3モードを試験する。

```text
UI-0
WPF Software Rendering

UI-1
WineD3D + Vulkan

UI-2
WineD3D + OpenGL
```

試験優先度:

```text
UI-0 → correctness baseline
UI-1 → accelerated candidate
UI-2 → diagnostic only
```

---

# 11. WPFソフトウェア描画

初期検証:

```bash
wine reg add \
  "HKCU\Software\Microsoft\Avalon.Graphics" \
  /v DisableHWAcceleration \
  /t REG_DWORD \
  /d 1 \
  /f
```

まずこれで、

- UI全体
- ポップアップ
- コンテキストメニュー
- AvalonDock
- AvalonEdit
- スクロール
- タイムライン
- 設定画面

が正常になるか確認する。

重要:

これはYMM4全体のGPU機能を無効化する設定とは扱わない。

**WPF UIだけのcorrectness baseline**である。

---

# 12. 日本語フォント

Wine 11.10ではWPFフォントフォールバックの不具合がmacOSで実際に報告されている。

ASCIIのハイフンさえ豆腐になるケースが確認されている。

また2026年にはWine側でも日本語等CJK UIフォントの既定フォールバック改善作業が進んでいる。

したがって日本語フォントを「見えたからOK」にしない。

テスト文字列:

```text
YMM4M - 2026
あいうえお
アイウエオ
漢字表示確認
！？。、・「」『』
ABC xyz 0123456789
― - – —
♪ ★ ☆
😀 🐟
```

さらに、

- Bold
- Italic
- フォント変更
- 縁取り
- 影
- ルビ
- 行間
- 文字間隔
- 複数行
- 半角全角混在

を検証する。

Microsoftフォントを権利確認なしにYMM4Mへ同梱しない。

Wine font replacementを使う場合も設定をコードに隠さず、

```text
FontProfile
```

として明示的に管理する。

---

# 13. IME

日本語IMEを独立テスト項目にする。

最低限:

```text
ひらがな
カタカナ
漢字変換
変換候補
Enter確定
Space変換
左右カーソル
Backspace
複数文節変換
```

を確認。

さらに、

```text
IME変換中に
YMM4ショートカットが誤発火しない
```

ことをテストする。

---

# 14. DPI / Retina

高DPIは後回しにしない。

YMM4 v4.55.1.1自身もUI拡大率・画面拡大率による文字ぼやけを修正している。

CrossOverもHigh Resolution Modeについて「すべてのアプリが正常描画するわけではない」と明記している。

以下を試験:

```text
100%
125%
150%
200%
```

および、

- 内蔵Retina
- 外部ディスプレイ
- ディスプレイ間移動

を検査する。

初期リリースでは「鮮明さ」より「レイアウト正常」を優先する。

---

# 15. EditRenderPlane — D2D / D3D11

YMM4公式プラグインサンプルでも`Vortice.Direct2D1`等が直接参照されている。

比較対象:

```text
WineD3D

vs

DXMT
```

DXMTはD3D10/11をMetalへ持っていくためのプロジェクトである。

CrossOver 26でもDXMTはD3D11用Metal backendとして提供されている。

重要:

**DXMTはWPFのD3D9問題を解決するものではない。**

---

# 16. DXMT評価

DXMTを最初から必須にしない。

同一プロジェクトについて、

```text
WineD3D
DXMT
```

で比較する。

評価:

- プレビューが出るか
- 色
- アルファ
- テキスト
- 回転
- 拡縮
- マスク
- ぼかし
- クロマキー
- トランジション
- フレーム同期
- GPUエラー
- device lost
- メモリリーク
- 描画速度

Windows基準画像と比較する。

---

# 17. DXMTライセンス

DXMTは現在MITではない。

現在のmainは、

```text
LGPL-2.1-or-later
```

である。旧MITはv0.80まで。

したがって、

```text
YMM4M Original Code → MIT
DXMT → LGPL-2.1-or-later
```

として分離する。

DXMTソースをMITディレクトリへコピーしてはいけない。

---

# 18. ComputePlane — D3D12

YMM4はComputeSharpを含む。

ComputeSharpはDX12/D2D/HLSLを利用する。

そのためD3D11だけ完全でも、YMM4のすべての映像処理が完全になるとは限らない。

候補:

### A. D3DMetal

長所:

- D3D11/12
- Metalへの直接変換
- Apple Silicon向け

CrossOver 26でもD3D11/12 backendとして利用される。

短所:

- Apple Game Porting Toolkit由来
- OSS YMM4Mへの再配布条件を別途確認する必要がある

したがって公開版へ無条件同梱しない。

---

## B. vkd3d + Vulkan/MoltenVK系

長所:

- OSS構成を作りやすい

短所:

- macOS/Vulkan変換がさらに一段増える
- D3D12互換性・性能を実測する必要がある

---

## C. D3D12機能をExperimental扱い

初期版ではこれが最も現実的。

まずD3D12を使わないTier A編集機能を完成させる。

どのYMM4機能がD3D12を実際に必要とするかログから分類する。

---

# 19. DirectML

YMM4には、

```text
Microsoft.ML.OnnxRuntime.DirectML
```

が含まれている。

DirectML GPU経路は初期保証対象にしない。

機能ごとに、

```text
CPU fallback可能
→ Tier B

DirectML必須
→ Tier C
```

へ分類する。

---

# 20. WebRenderPlane — WebView2

現行YMM4にはMicrosoft.Web.WebView2が含まれている。

2026年WineでもWebView2は難所。

Wine 11.1で、Chromium/WebView2がD3D11共有textureとDirectCompositionを利用する経路で白・黒画面になる問題が詳細に報告されている。

Wine開発者も、

- dcomp
- multiprocess surfaces
- sandbox

など追加対応が必要としている。

したがってWebView2を、

```text
YMM4起動必須コンポーネント
```

と仮定もしないし、

```text
完全に問題ない
```

とも仮定しない。

WineログでYMM4のどの画面がWebView2を起動するか確認する。

---

# 21. WebView2 workaround

Wine側の報告にはWindows 8モードを使う回避例がある。

しかし、

```text
YMM4 prefix全体をWindows 8
```

にしてはいけない。

YMM4はWindows 10 version 2004以降を対象としている。

必要なら、

```text
msedgewebview2.exe
```

だけにアプリ単位のWindows version overrideを試験する。

必ずA/Bテストする。

---

# 22. Media Architecture

YMM4ではFFmpeg経路とMedia Foundation経路が別に存在する。

2026年6月の公式更新でも、

- FFmpeg動画読み込み
- MediaFoundation動画読み込み

が別々に修正されている。

またv4.53.0.6では、

- MediaFoundation動画出力高速化
- FFmpeg動画出力のハードウェアエンコード
- GPUによるNV12変換

などが入っている。

したがって、

```text
Media Foundationを完璧に動かさなければ
YMM4が使えない
```

とは考えない。

---

# 23. 動画入力方針

Tier A:

```text
FFmpeg Reader
```

を優先する。

試験形式:

```text
H.264 + AAC MP4
H.264 + PCM
MOV
WebM
WAV
MP3
PNG
JPEG
GIF
```

Windows Store codec extensionsに依存する形式はTier B/C。

公式YMM4ページもHEVC等についてWindows拡張機能を利用する構成を案内しているため、Wine環境でそれを当然利用可能とは仮定しない。

---

# 24. 動画出力の大幅改善案

ここは前回案から大きく改善する。

YMM4の公式プラグインAPIには、

```text
動画出力プラグイン
```

が存在する。

公式サンプルでは、

```csharp
public void WriteAudio(float[] samples)
```

と、

```csharp
public void WriteVideo(byte[] frame)
```

を実装する`IVideoFileWriter`が公開されている。

`IVideoFileWriterPlugin`には、

```csharp
CreateVideoFileWriter(string path, VideoInfo videoInfo)
```

もある。

これは非常に重要。

---

# 25. YMM4MBridge を作る

YMM4M独自のYMM4プラグイン:

```text
YMM4MBridge
```

を作る。

構成:

```text
YMM4 Windows process
       │
       │ IVideoFileWriter
       ▼
YMM4MBridge.dll
       │
       │ authenticated IPC
       ▼
YMM4MEncoder
ARM64 native macOS process
       │
       ├─ FFmpeg
       └─ VideoToolbox
```

これにより、

**YMM4が生成した完成フレームと音声をMacネイティブ側へ渡してエンコードできる。**

---

# 26. Native Export方式の利点

Windows側の、

- Media Foundation
- Windows GPU encoder
- NVENC
- D3D11 video
- Windows codec extension

への依存を減らせる。

Apple側では最終的に、

```text
VideoToolbox
H.264
HEVC
```

を利用できる。

ただし最初からVideoToolboxへ行かない。

---

# 27. Native Export実装順

### Stage 1

IPC接続。

### Stage 2

フレームを受信してrawファイルに保存。

### Stage 3

音声をraw PCMとして保存。

### Stage 4

native FFmpegによるsoftware encode。

### Stage 5

Windows版出力との映像比較。

### Stage 6

VideoToolbox H.264。

### Stage 7

VideoToolbox HEVC。

これにより問題が、

```text
YMM4描画
IPC
encoder
```

のどこにあるか分離できる。

---

# 28. WriteVideoの形式を推測しない

公式サンプルでは`byte[] frame`であることまでは確認できるが、

- RGBA
- BGRA
- stride
- top-down/bottom-up
- premultiplied alpha

等はサンプルだけでは確定できない。

したがって実装前に、

```text
VideoInfo
IVideoFileWriter
YukkuriMovieMaker.Plugin.dll公開API
```

の型情報を調査する。

公開APIから確定できなければ、Windows上でテストwriterを作り、

```text
赤
緑
青
透明
グラデーション
```

を書き出してメモリ配列を実測する。

絶対にBGRA等を推測で固定しない。

---

# 29. IPC

初期方式:

```text
127.0.0.1 TCP
```

を推奨。

理由:

Wine Windows processとネイティブmacOS processの双方から扱いやすいため。

セキュリティ条件:

```text
bind = 127.0.0.1 only
random port
random session token
protocol version
maximum frame size
maximum message size
timeout
```

を必須にする。

LANへbindしない。

---

# 30. IPC Protocol

例:

```text
HELLO
protocolVersion
sessionToken

VIDEO_INFO
width
height
fpsNumerator
fpsDenominator
pixelFormat
stride

AUDIO_INFO
sampleRate
channelCount
sampleFormat

VIDEO_FRAME
frameNumber
size
data

AUDIO_CHUNK
sampleStart
sampleCount
data

END
```

実際のpixel/audio形式が判明した後で確定する。

---

# 31. Native Helperを別プロセスにする理由

AppleはRosettaについて、

**同一プロセスでarm64コードとx86_64コードを混在できない**

と明記している。

したがって、

```text
Wine/YMM4 process
```

と、

```text
ARM64 native helper
```

は明確に別プロセスにする。

これは将来ARM64 Wineへ移行しても良い境界になる。

---

# 32. 音声再生

基本音声再生について、

- WAV
- MP3
- stereo
- mono
- 44.1kHz
- 48kHz
- 音量
- パン
- 再生速度
- 音程

を試験する。

タイムライン映像とのA/V同期も測る。

単に「音が鳴った」で合格にしない。

---

# 33. 録音

v4.53系以降には録音ツールがある。

macOSではマイク権限が別途必要。

Tier Bとする。

YMM4M.app側には必要に応じ、

```text
NSMicrophoneUsageDescription
```

を設定する。

Wine側オーディオキャプチャがmacOS入力へ正しく接続するかテストする。

---

# 34. 音声合成

一括で扱わない。

分類:

```text
A. Cloud HTTP API
B. localhost HTTP API
C. Windows COM / SAPI
D. Windows GUIアプリ連携
E. native DLL
```

---

# 35. Cloud TTS

YMM4公式ページには複数のクラウドTTSがある。

HTTP/TLS主体ならWineでも成立しやすい。

ただし、

```text
APIキー入力
TLS
証明書
HTTP2
認証
音声ダウンロード
```

を実測する。

Tier B。

---

# 36. VOICEVOX等localhost型

Macネイティブ版エンジンが存在するサービスの場合、

```text
YMM4 under Wine
 ↓ HTTP
127.0.0.1
 ↓
native macOS engine
```

が成立する可能性が高い。

各サービスごとに実測。

---

# 37. Windows専用音声ソフト

A.I.VOICE、CeVIO、SAPI等は別プロジェクトに近い難易度を持つ。

Wine上でもう一つWindowsアプリを動かす必要がある場合、

```text
YMM4が動く
```

ことと、

```text
音声ソフトが動く
```

ことは別問題。

Tier Cとする。

---

# 38. VST3

YMM4 v4.55.0.0でVST3プラグイン機能が追加されている。

v4.55.1.1には、

```text
YukkuriMovieMaker.Vst3Scanner.exe
```

が存在する。

原則としてWindows版YMM4からロードできるのはWindows VST3。

macOS ARM64 VST3をそのままWindowsプロセスへロードすることはできない。

対応レベル:

```text
pure Win64 VST3
→ 試験対象

iLok / DRM
→ Experimental

GPU/vendor-specific
→ Experimental / Unsupported

macOS-native VST3
→ direct loading unsupported
```

---

# 39. OpenFX

v4.55.0.0でOpenFX対応が追加された。

また、

```text
YukkuriMovieMaker.OfxScanner.exe
```

も存在する。

VST3と同様、

```text
Windows OpenFX
```

と、

```text
macOS OpenFX
```

を混同しない。

---

# 40. Plugin Safe Mode

YMM4Mには、

```text
Launch without third-party plugins
```

を必ず用意する。

実装:

YMM4起動前に第三者plugin directoryを一時的に別名へ切り替える等、安全で元に戻せる方式を調査して採用する。

YMM4標準ファイルは削除しない。

---

# 41. ファイルシステム

WineではMacパスがWindows drive pathとして見える。

プロジェクトファイル内のパスをYMM4M側で無理にmacOS形式へ書き換えない。

YMM4との互換性が壊れる。

代わりに固定drive mappingを使用する。

推奨:

```text
M:
```

をユーザーが指定したMedia Rootへ割り当てる。

例:

```text
M:\Videos\project1\clip.mp4
```

これにより毎回同じWine prefixで安定する。

---

# 42. Z:ドライブ

Wineの典型的な、

```text
Z: → /
```

を無条件に利用者へ露出する設計にはしない。

セキュリティ・プライバシーのため、

```text
M: → selected media directory
```

を標準にする。

必要なユーザーだけAdvanced modeで広いfilesystem accessを許可する。

---

# 43. macOS Finder統合

YMM4M.appへ以下のDocument Typesを登録する。

```text
.ymmp
.ymme
```

Finderで`.ymmp`を開いた場合、

```text
Finder
 ↓
YMM4M.app
 ↓
Mac path → Wine path
 ↓
YukkuriMovieMaker.exe project.ymmp
```

へ変換する。

`.ymme`についてはYMM4公式プラグイン形式であり、公式サンプルではzipを`.ymme`へ変更して配布する方式が案内されている。

---

# 44. ドラッグ&ドロップ

必須テスト:

```text
Finder → timeline
Finder → file field
Finder → project
Photos等からのvirtual file
```

YMM4 v4.53.0.6でもIStorage仮想ファイルのdrag & drop修正が入っており、この部分がWindows shell APIに依存する可能性がある。

Tier Aでは通常ファイルのdrag & dropを必須。

virtual fileはTier B。

---

# 45. Clipboard

最低:

```text
plain text
image
YMM4 item copy/paste
YMM4 effect copy/paste
```

を確認する。

macOS clipboard ↔ Wine clipboardの文字コード・画像形式を試験。

---

# 46. CLI動画出力を自動テストへ利用する

YMM4 v4.53.0.0からCLI動画エンコードが公式に追加されている。

詳細は、

```text
./YukkuriMovieMaker.exe -h
```

で取得する仕様。

引数をWeb情報から推測しない。

Phase 0で、

```bash
wine YukkuriMovieMaker.exe -h
```

を実行し、

```text
evidence/ymm4-cli-help-4.55.1.1.txt
```

へ保存する。

これを自動回帰テストに利用する。

---

# 47. Windows Reference Oracle

「Macで正常」という判定にはWindows版との比較が必要。

テスト専用Windows環境を用意してよい。

VMでもよい。

ただし製品実行基盤としてVMを使ってはいけない。

基準プロジェクト:

```text
1280x720
30fps
10 sec
```

内容:

```text
PNG
JPEG
WAV
MP3
MP4
日本語テキスト
図形
移動
拡大縮小
回転
フェード
ぼかし
縁取り
影
```

---

# 48. Render Parity Test

WindowsとMacで、

```text
frame 0
frame 30
frame 60
frame 150
frame 299
```

等を取得する。

H.264ファイルのバイナリ一致を求めない。

エンコーダ差があるため。

可能ならlossless出力またはデコード後RGBで比較。

見る項目:

```text
pixel difference
alpha
geometry
text layout
colors
frame timing
audio timing
```

---

# 49. Compatibility Registry

機能状態をMarkdownだけで管理しない。

```text
compatibility/features.yaml
```

を作る。

例:

```yaml
- id: core.ui.main
  tier: A
  status: untested
  dependencies:
    - wpf
    - d3d9
  tests:
    - UI001

- id: core.video.preview
  tier: A
  status: untested
  dependencies:
    - d2d
    - d3d11
  tests:
    - VID001
```

Status:

```text
untested
pass
pass_with_workaround
partial
fail
crash
unsupported
```

のみ。

---

# 50. Wineログ

通常:

```text
WINEDEBUG=+timestamp,+pid,+tid,+seh,+loaddll
```

必要時のみ:

```text
+d3d
+d3d9
+dxgi
+d3d11
+dwrite
+font
+gdi
+ole
+combase
+mf
+winhttp
```

等を追加。

`+relay`を常時有効にしない。

---

# 51. CrossOverの役割

CrossOverをYMM4Mへ同梱しない。

CrossOverは、

```text
Compatibility Oracle
```

として利用する。

2026年時点のCrossOver 26は、

- DXMT
- D3DMetal
- DXVK
- WineD3D

を選択可能。

例えば、

```text
CrossOver + DXMT → works
Upstream Wine + DXMT → fails
```

なら、

「Wineでは無理」

ではなくCrossOverとの差分を調べる。

---

# 52. 実装方式比較

| 方式 | Core互換性 | 開発量 | OSS | 将来性 | 採用 |
|---|---:|---:|---:|---:|---|
| 素のWineだけ | △〜○ | 小 | ◎ | ○ | 基準用 |
| Wine + YMM4専用設定 | ○ | 中 | ◎ | ○ | 採用 |
| Wine + 少数patch | ○〜◎ | 中 | ◎ | ○ | 採用 |
| Wine + DXMT | ○〜◎ | 中 | ◎ | ◎ | 採用候補 |
| Wine + Bridge + Native Helper | ◎ | 中〜大 | ◎ | ◎ | 本命 |
| CrossOver依存 | ◎候補 | 小 | × | ◎ | 検証のみ |
| Windows VM | ◎ | 小 | ― | ◎ | 製品では不採用 |
| Windows API全面再実装 | × | 極大 | ◎ | △ | 不採用 |
| YMM4再実装 | × | 極大 | ◎ | ◎ | 不採用 |

推奨構成:

```text
Wine
+
YMM4専用設定
+
必要最小限のWine patch
+
DXMT
+
YMM4MBridge
+
macOS Native Host
```

---

# 53. Rosetta

現在のProduction backend:

```text
Windows x64
↓
x86_64 Wine
↓
Rosetta
↓
Apple Silicon
```

を第一候補とする。

ただし永続方式ではない。

AppleはRosettaを一般Intelアプリ向けにはmacOS 27までと明記している。

macOS 27リリースノートでは、

```text
macOS 28ではlegacy gamesを除くIntel softwareは非互換
```

と明示されている。

YMM4/Wineをlegacy game扱いできるとは仮定しない。

---

# 54. macOS 27

2026年8月24日時点ではmacOS 27 Golden GateはBetaとして扱う。

Production support対象として宣言しない。

Canaryテストのみ。

AppleはmacOS 27でIntel binary translationの扱い自体を変更しているため、26以前で動いたRosetta設定がそのまま成立すると仮定しない。

---

# 55. ARM64 Wine + FEX

2026年7月31日、CodeWeaversはARM64 native CrossOver for Mac Previewを公開した。

構成は、

```text
ARM64 Wine
+
macOS対応custom FEX
```

である。

ただしCodeWeavers自身が現在のARM64 buildについて、一般利用よりテスト向けの未成熟状態と説明している。

したがって、

```text
Arm64WineFEXBackend
```

はResearch backendとする。

---

# 56. upstream FEXをそのまま使ってはいけない

2026年7月時点のWine開発者間の議論では、

**upstream FEXはmacOSを現在対象としていない**

ことが明示されている。

CodeWeaversは独自にmacOS対応したFEXを利用している。

したがって、

```bash
git clone FEX
cmake
```

だけでmacOS版が完成すると考えてはいけない。

---

# 57. ARM64 Wineの重要な制約

2026年8月7日のWine開発者情報では、macOS 26.5で、

- x86互換向けTSO制御
- ARM64関連機構

が利用可能になった。

しかしrestricted entitlementが必要。

具体的には、

```text
com.apple.developer.cross-architecture-support
```

または開発用途の関連entitlementが必要と説明されている。

さらにWine側パッチも当時upstream化作業中。

よって、

**Wine 11.16 = そのままnative ARM64 macOS production runtime**

ではない。

---

# 58. SIP

Wine ARM64テストのためにSIP無効化を標準手順としてはいけない。

Wine開発者自身もSIP無効化を推奨していない。

YMM4Mの原則:

```text
SIP enabled
Gatekeeper enabled
normal macOS security
```

で動くこと。

それが不可能なbackendは研究用。

---

# 59. macOS 28について

現時点では、

```text
YMM4M supports macOS 28
```

とREADMEに書いてはいけない。

ARM64 Wine + FEXについて、

- OSS側実装
- entitlement
- public distribution
- Developer ID
- notarization
- FEX macOS implementation

がすべて解決してからサポート宣言する。

---

# 60. RuntimeBackend

Swift側:

```swift
protocol RuntimeBackend {
    var identifier: String { get }
    var supportLevel: RuntimeSupportLevel { get }

    func probe() async throws -> RuntimeProbeResult
    func prepare() async throws
    func launch(
        executable: URL,
        arguments: [String]
    ) async throws -> ProcessHandle
    func terminate() async throws
    func collectDiagnostics() async throws -> RuntimeDiagnostics
}
```

実装:

```text
RosettaWineBackend
Arm64WineFEXBackend
```

UIコードから直接`wine`を呼ばない。

---

# 61. 対応OS方針

初期開発対象:

```text
Apple Silicon only
```

macOS 14以降を候補とする。

ただしREADMEへ対応OSを確定記載する前に、

```text
macOS 14
macOS 15
macOS 26
```

の実機/VMテストを行う。

macOS 27 beta:

```text
Experimental
```

ARM64/FEX:

```text
macOS 26.5+
Research
```

最低OSは「SwiftUIがビルドできたから」ではなくWineを含めたE2Eテストで決定する。

---

# 62. macOS Native App

旧案の「Swift Packageだけ」は不足。

署名・entitlement・helper・Document Type等が必要になるため、

```text
Xcode macOS App Project
```

を主構成にする。

言語:

```text
Swift
SwiftUI
AppKit where necessary
```

CoreロジックはSwift Packageへ分割してよい。

---

# 63. Repository構造

```text
YMM4M/
├── README.md
├── LICENSE
├── THIRD_PARTY_NOTICES.md
├── SECURITY.md
├── CONTRIBUTING.md
├── AGENTS.md
├── ARCHITECTURE.md
├── COMPATIBILITY.md
├── STATUS.md
├── LEGAL.md
├── runtime.lock.json
├── .gitignore
│
├── app/
│   ├── YMM4M.xcodeproj/
│   └── YMM4M/
│       ├── App/
│       ├── Launcher/
│       ├── Runtime/
│       ├── Integration/
│       ├── Diagnostics/
│       ├── Bridge/
│       └── Resources/
│
├── bridge/
│   ├── YMM4MBridge/
│   │   ├── YMM4MBridge.csproj
│   │   ├── FileWriter/
│   │   ├── Voice/
│   │   └── Protocol/
│   │
│   └── NativeEncoder/
│
├── runtime/
│   ├── recipes/
│   ├── patches/
│   │   └── wine/
│   ├── build/
│   └── profiles/
│       ├── wpf-software/
│       ├── wined3d-vulkan/
│       └── dxmt/
│
├── tools/
│   ├── inspect-system.sh
│   ├── inspect-ymm4.py
│   ├── inspect-pe.py
│   ├── inspect-dotnet.py
│   ├── create-prefix.sh
│   ├── run-ymm4.sh
│   ├── collect-wine-log.sh
│   └── compare-frames.py
│
├── compatibility/
│   └── features.yaml
│
├── tests/
│   ├── unit/
│   ├── contracts/
│   ├── fixtures/
│   └── e2e-local/
│
├── evidence/
│   └── README.md
│
└── .github/
    └── workflows/
```

---

# 64. ライセンス

## YMM4M original code

MIT。

```text
MIT License

Copyright (c) 2026 Yuki_Orita
```

標準MIT本文を使用。

---

## DXMT

LGPL-2.1-or-later。

---

## Wine

利用するWine revisionに含まれる`COPYING.LIB`等をビルド時に機械的に保存し、そのライセンス義務に従う。

WineコードをMITへ変更しない。

---

## FEX

導入時点のupstream/custom fork双方のライセンスを記録。

custom macOS patchの権利関係まで確認。

---

# 65. 「YMM4MはMIT」の正確な意味

正しくは、

```text
YMM4M original source:
MIT
```

である。

配布パッケージ全体を、

```text
everything MIT
```

とは言わない。

第三者ランタイムを含む場合はmulti-license distribution。

---

# 66. YMM4本体

GitHubへ入れない。

```text
YukkuriMovieMaker.exe
YukkuriMovieMaker*.dll
AquesTalk files
YMM4 icon/logo
YMM4 official ZIP
```

をcommitしない。

YMM4M独自アイコンを作る。

---

# 67. YMM4導入

安全側の初期仕様:

```text
YMM4Mを起動
↓
YMM4が未導入
↓
「公式YMM4 ZIPを選択」
↓
ユーザーが公式サイトから取得したZIPを選択
↓
YMM4Mが検査
↓
展開
```

とする。

自動ダウンロードは公式側の配布条件を確認してから追加。

スクレイピング前提にしない。

---

# 68. GitHub初期化

```bash
gh auth status

mkdir -p ~/Developer/YMM4M
cd ~/Developer/YMM4M

git init -b main

git config user.name
git config user.email
```

`user.name`が未設定の場合のみ:

```bash
git config --global user.name "Yuki_Orita"
```

メールアドレスを推測して設定しない。

---

# 69. Repository作成

初期ファイル・LICENSE・READMEを作成して最初のcommit後、

```bash
gh repo create YMM4M \
  --public \
  --source=. \
  --remote=origin \
  --description "Unofficial macOS compatibility runtime for YukkuriMovieMaker4"
```

を使用する。

認証済みGitHubアカウント名を推測しない。

---

# 70. Phase 0 — Environment Truth

実装を始める前に:

```bash
sw_vers
uname -a
uname -m
system_profiler SPHardwareDataType
xcodebuild -version
swift --version
clang --version
git --version
gh --version
```

保存:

```text
evidence/environment.json
```

---

# 71. YMM4 Binary Truth Gate

最新公式YMM4 ZIPをユーザーに選択させる。

SHA-256:

```bash
shasum -a 256 YMM4.zip
```

記録:

```json
{
  "version": "4.55.1.1",
  "sha256": "...",
  "acquiredAt": "...",
  "source": "official"
}
```

---

# 72. PE Inventory

Python venv:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install pefile
```

すべての、

```text
.exe
.dll
```

について、

```text
path
size
sha256
PE machine
managed/native
subsystem
imports
file version
product version
```

を出す。

PE Machine:

```text
0x014c I386
0x8664 AMD64
0xaa64 ARM64
0xa641 ARM64EC
```

保存:

```text
evidence/ymm4-4.55.1.1-inventory.json
```

このGateがpassするまでRuntime Architectureをハードコードしない。

---

# 73. .NET Inventory

調査:

```text
*.runtimeconfig.json
*.deps.json
coreclr.dll
hostfxr.dll
hostpolicy.dll
Microsoft.WindowsDesktop.App
```

分類:

```text
SELF_CONTAINED
FRAMEWORK_DEPENDENT
UNKNOWN
```

`UNKNOWN`のまま次へ進まない。

---

# 74. Native Dependency Inventory

特に確認:

```text
ffmpeg
WebView2
DirectML
ComputeSharp-related
VST scanner
OFX scanner
MSVC runtime
Speech SDK native DLL
ONNX native DLL
OpenCV native DLL
```

architectureを記録。

---

# 75. Clean-roomの定義

YMM4Mでは「YMM4のソースを再現する」クリーンルーム方式を取らない。

互換性検証は、

```text
public documentation
public plugin API
documented Windows APIs
PE metadata
runtime logs
Windows black-box behavior
```

に基づく。

YMM4内部アルゴリズムをコピーしない。

---

# 76. Phase 1 — Three Runtime Baseline

同じYMM4 ZIP・同じテストprojectについて、

```text
A: Wine 11.0
B: Wine 11.16
C: CrossOver 26.3.0
```

を比較。

CrossOver:

```text
WineD3D
DXMT
D3DMetal
```

それぞれ必要に応じ試す。

---

# 77. Baseline Test 01 — Boot

チェック:

```text
process starts
splash appears
main window appears
no fatal exception
menus appear
Japanese text appears
settings opens
close works
second launch works
```

Tag:

```text
milestone-ui-boot
```

---

# 78. Baseline Test 02 — UI

```text
AvalonDock
timeline scrolling
zoom
popup
context menu
property editor
color picker
font selector
file dialog
keyboard shortcut
IME
clipboard
```

---

# 79. Baseline Test 03 — Minimal Project

```text
1280x720
30fps
10 sec

PNG
WAV
Text
```

操作:

```text
create
place
move
resize
preview
save
exit
reopen
preview again
```

Tag:

```text
milestone-core-edit
```

---

# 80. Baseline Test 04 — Video

H.264/AAC MP4。

```text
import
thumbnail
seek
split
timeline playback
audio sync
preview
save
reopen
```

---

# 81. Baseline Test 05 — Effects

Core test effect setを固定する。

少なくとも:

```text
opacity
position
scale
rotation
crop
blur
outline
shadow
chroma key
color adjustment
transition
```

Windows referenceと比較。

---

# 82. Baseline Test 06 — Export

順番:

```text
YMM4 FFmpeg software
↓
YMM4 native available output
↓
YMM4MBridge software
↓
YMM4MBridge VideoToolbox
```

Media Foundation hardware outputを最初にデバッグしない。

---

# 83. YMM4MBridge project

`.csproj`は現行公式サンプルと同様、

```xml
<TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>
<UseWPF>true</UseWPF>
```

を基準にする。

ただしYMM4MBridgeのUI依存は最小にする。

---

# 84. YMM4参照DLL

Bridge build時に、

```text
YukkuriMovieMaker.Plugin.dll
YukkuriMovieMaker.Controls.dll
```

等をユーザーのYMM4 directoryから参照する。

Gitへコピーしない。

公式サンプルもYMM4インストール先DLLを参照する方式である。

---

# 85. Bridge Version Gate

起動時にYMM4 versionを確認。

例:

```text
tested:
4.55.1.1
```

未知version:

```text
YMM4MBridge has not been validated against this YMM4 version.
```

と表示。

クラッシュより明示的警告を優先。

---

# 86. Native Encoder

ARM64。

第一実装:

```text
YMM4MEncoder
```

責務:

- IPC接続
- frame validation
- audio validation
- output file
- progress
- cancellation
- FFmpeg subprocess/native library
- later VideoToolbox

YMM4M GUIプロセス自身に巨大エンコード責務を持たせない。

---

# 87. Security

Bridge IPC:

```text
localhost only
authentication token
length prefix
strict message validation
maximum frame
protocol version
```

不正pluginからNative Hostへの任意ファイル操作を許可しない。

---

# 88. Logging Redaction

削除:

```text
home username
API keys
OAuth tokens
Authorization headers
password
full personal paths where unnecessary
```

Diagnosticsへ含める:

```text
YMM4M version
YMM4 version
Wine commit
DXMT commit
renderer profiles
macOS
CPU architecture
backend
.NET deployment model
WebView2 presence
logs
```

---

# 89. runtime.lock.json

例:

```json
{
  "schema": 1,
  "ymm4": {
    "testedVersion": "4.55.1.1",
    "sha256": null
  },
  "wine": {
    "channel": "candidate",
    "version": null,
    "commit": null,
    "buildFlags": []
  },
  "graphics": {
    "uiProfile": "wpf-software",
    "editProfile": "wined3d",
    "dxmtCommit": null,
    "d3d12Profile": "disabled"
  },
  "arm64": {
    "enabled": false,
    "wineCommit": null,
    "fexCommit": null
  }
}
```

最初から11.16をrelease runtimeとして書かない。

実測後に埋める。

---

# 90. Wine patch原則

YMM4固有patchを入れる前に最小再現プログラムを作る。

順序:

```text
YMM4 failure
↓
Wine log
↓
API/component identified
↓
minimal Windows reproducer
↓
Windows reference result
↓
Wine result
↓
generic fix
↓
regression test
↓
Wine patch
```

可能ならupstreamへ出せるgeneric fixにする。

---

# 91. patches/

```text
runtime/patches/wine/
```

例:

```text
0001-wined3d-fix-xxx.patch
0002-dwrite-fix-xxx.patch
```

各patchにmetadata:

```text
Reason
Affected YMM4 version
Affected Wine revision
Reproducer
Windows behavior
Expected removal condition
Upstream issue/MR
```

---

# 92. WPF GL問題への対応

現在確認されているWPF問題ではWineD3D OpenGL backendが失敗し、Vulkan backendが成功したケースがある。

したがって、

```text
WPF software
```

で正常化した後、

```text
wined3d Vulkan
```

を必ず試す。

これが安定すればUIをsoftware rendererのまま永久運用する必要はない可能性がある。

---

# 93. DXMT 1.0前提にしない

DXMTでは2026年4月時点で1.0 Release Planが進行中であり、cross-process rendering等も開発課題に含まれている。

そのため、

```text
latest main
```

を無条件production依存にしない。

動作確認済みcommitを固定。

---

# 94. Performanceはcorrectness後

優先順位:

```text
1 correctness
2 stability
3 repeatability
4 performance
```

YMM4が高速だが1/100回壊れる状態は不合格。

---

# 95. プレビュー性能測定

計測:

```text
720p30
1080p30
1080p60
4K30
```

シーン:

```text
text only
image
H264 video
3 effects
10 effects
```

記録:

```text
average fps
p95 frame time
CPU %
memory
GPU %
dropped frames
```

---

# 96. Export Performance

比較:

```text
YMM4 FFmpeg software
YMM4 Windows hardware path where available
YMM4M Native FFmpeg
YMM4M VideoToolbox
```

画質条件を可能な限り揃える。

速度だけ比較しない。

---

# 97. Auto Update

YMM4MのupdateとYMM4のupdateを分離。

```text
YMM4M Runtime Update
YMM4 Application Update
```

は別状態機械。

YMM4 update前に既存versionを残す。

```text
YMM4/
├── 4.55.1.1/
└── next/
```

rollback可能にする。

---

# 98. YMM4公式アップデータ

最初はYMM4の自動アップデータがWine内で正常に働くか試験する。

動くならそれを尊重する。

YMM4M独自update機構でYMM4内部を勝手に書き換えない。

---

# 99. Compatibility after update

新YMM4 version検出時:

```text
known compatible
unknown
known broken
```

に分類。

未知版なら、

```text
Continue
Use tested 4.55.1.1
```

を選べる。

---

# 100. YMM4 v4.55.1.1 scanner processes

現在のv4.55.1.1ではVST3/OFX scannerの存在が公式に確認されている。

したがってprocess managerは、

```text
YukkuriMovieMaker.exe
ffmpeg
voice engine
Vst3Scanner
OfxScanner
WebView2 processes
```

を個別に観測できるようにする。

---

# 101. Process tree logging

起動時に、

```text
process
parent pid
architecture
exit code
start time
end time
```

を記録。

未知child processもログへ出す。

---

# 102. GitHub Actions

通常CI:

```text
Swift build/test
C# protocol unit tests
Python tests
shellcheck
license check
JSON/YAML validation
```

YMM4本体をCIへアップロードしない。

---

# 103. Bridge CI

YMM4 proprietary DLLを必要とするbuildは、

```text
local integration
```

へ分離。

公開可能なProtocol/Core部分は通常CI。

---

# 104. Runtime build CI

Wine/DXMT full buildは毎PRで行わない。

```text
workflow_dispatch
scheduled compatibility build
release candidate
```

へ分離。

GitHubのmacOS runner名は実装時点の公式GitHub仕様を確認してから固定。

---

# 105. Xcode / Signing

開発:

```text
Development signing
```

Release:

```text
Developer ID Application
Hardened Runtime
notarytool
stapler
```

App Sandboxは初期版では使用しない。

---

# 106. nested signing

Wineランタイムを.appへ含める場合、

- executable
- dylib
- helper
- framework

を内側から署名する。

```text
codesign --deep
```

だけを恒久的なrelease solutionとしない。

---

# 107. ARM64 backend entitlement

`Arm64WineFEXBackend`を試験するときは、2026年8月現在必要とされるcross-architecture entitlementを正式なApple Developer手順で取得する。

entitlement取得不能なら、

```text
backend unavailable
```

とする。

セキュリティを迂回しない。

---

# 108. Release Support Matrix

README例:

```text
macOS 14     Testing
macOS 15     Testing
macOS 26     Primary
macOS 27     Experimental / Beta
macOS 28     Unsupported until ARM64 backend is production ready
```

実測後に書き換える。

---

# 109. v0.1 — Discovery

完成条件:

```text
repository
licenses
native launcher
binary inventory
.NET inventory
Wine 11.0 baseline
Wine 11.16 baseline
CrossOver baseline
compatibility matrix
```

---

# 110. v0.2 — UI

```text
YMM4 launch
Japanese UI
IME
timeline
dialogs
clipboard
save/reopen
```

Tag:

```text
milestone-ui-stable
```

---

# 111. v0.3 — Core Editing

```text
PNG
JPEG
WAV
MP3
text
shape
animation
basic effects
```

---

# 112. v0.4 — Video

```text
H264/AAC import
seek
split
preview
audio sync
FFmpeg software export
```

---

# 113. v0.5 — Native Export

```text
YMM4MBridge
IPC
native encoder
H264 software
VideoToolbox H264
```

---

# 114. v0.6 — GPU

```text
DXMT
WineD3D comparison
WPF Vulkan test
D3D12 inventory
```

---

# 115. v0.7 — Voice

```text
cloud TTS
VOICEVOX-class localhost engine
built-in voice testing
```

---

# 116. v0.8 — Plugins

```text
managed YMM4 plugins
VST3 scanner
OpenFX scanner
safe mode
```

---

# 117. v0.9 — Distribution

```text
codesign
notarization
automatic diagnostics
rollback
update handling
third-party source compliance
```

---

# 118. v1.0 Release Gate

Tier Aがすべて、

```text
PASS
```

または、

```text
PASS_WITH_DOCUMENTED_WORKAROUND
```

であること。

`PARTIAL`がTier Aに残るならv1.0にしない。

---

# 119. macOS 28 Gate

macOS 28対応を宣言する条件:

```text
ARM64 Wine boots reliably
x64 YMM4 executes via supported translator
no SIP disabling
normal signed application
notarization succeeds
public distribution works
core Tier A passes
DXMT/native graphics works
bridge works
```

すべて達成すること。

---

# 120. 最初に作るIssues

```text
P0: Capture YMM4 4.55.1.1 binary inventory
P0: Determine current YMM4 .NET deployment model
P0: Determine YMM4 executable architecture
P0: Inventory native DLL architectures

P1: Establish Wine 11.0 baseline
P1: Establish Wine 11.16 baseline
P1: Establish CrossOver 26.3.0 baseline

P1: Test WPF software rendering
P1: Test wined3d Vulkan WPF rendering
P1: Test Japanese font fallback
P1: Test Japanese IME
P1: Test Retina/DPI

P1: Complete minimal editing workflow
P1: Verify project save/reopen
P1: Verify Finder file mapping

P2: Test FFmpeg reader
P2: Test audio playback
P2: Test H264/AAC preview
P2: Test FFmpeg software export

P2: Build YMM4MBridge protocol
P2: Implement IVideoFileWriter bridge
P2: Implement native software encoder
P2: Implement VideoToolbox H264

P2: Benchmark WineD3D vs DXMT
P2: Inventory D3D12-dependent features

P3: Test WebView2
P3: Test transcription
P3: Test DirectML CPU/GPU paths
P3: Test cloud TTS
P3: Test localhost TTS

P3: Test VST3 scanner
P3: Test OpenFX scanner

Research: Prototype ARM64 Wine backend
Research: Evaluate macOS-compatible FEX
Research: Validate cross-architecture entitlement
Research: Investigate macOS 28 distribution path

Release: Implement signing
Release: Implement notarization
Release: Complete third-party license audit
```

---

# 121. AGENTS.mdへ入れる最重要規則

```text
1. Never guess undocumented YMM4 behavior.
2. Record evidence before changing compatibility code.
3. Do not decompile proprietary YMM4 implementation without explicit legal review.
4. Never commit YMM4 binaries.
5. Never commit Microsoft proprietary runtimes/fonts unless redistribution rights are verified.
6. Do not treat DXMT as MIT.
7. Do not distribute CrossOver.
8. Do not depend permanently on Rosetta.
9. Do not disable SIP.
10. Do not disable Gatekeeper globally.
11. Do not use sudo unless absolutely required and documented.
12. Separate WPF, D3D11, D3D12 and WebView2 issues.
13. Prefer FFmpeg before attempting full Media Foundation compatibility.
14. Prefer official YMM4 plugin APIs over binary patching YMM4.
15. Keep Wine patches small and upstreamable.
16. Every workaround must document why it exists and when it can be removed.
17. Every compatibility claim requires a reproducible test.
18. Do not mark an untested feature as supported.
19. Do not modify a user's .ymmp project silently.
20. Keep the native macOS host ARM64.
```

---

# 122. 開発開始順序

開発AIは以下の順番を守る。

```text
01 gh auth status
02 inspect Mac
03 create YMM4M repository
04 add MIT license
05 add third-party licensing structure
06 create Xcode ARM64 launcher
07 acquire official YMM4 v4.55.1.1
08 calculate SHA-256
09 inspect PE architecture
10 inspect .NET deployment
11 inspect native binaries
12 save evidence
13 test Wine 11.0
14 test Wine 11.16
15 test CrossOver 26.3
16 establish WPF software baseline
17 test WPF Vulkan backend
18 solve Japanese fonts
19 solve Japanese IME
20 test file dialogs
21 create minimal project
22 save and reopen
23 test FFmpeg media
24 test audio/video preview
25 create Windows reference renders
26 compare rendering
27 test WineD3D
28 test DXMT
29 map D3D12 features
30 test software export
31 create YMM4MBridge
32 implement FileWriter protocol
33 build ARM64 NativeEncoder
34 validate raw frames/audio
35 implement native FFmpeg export
36 implement VideoToolbox H264
37 test cloud/local TTS
38 isolate WebView2
39 test VST3/OpenFX
40 implement diagnostics
41 implement update/rollback
42 sign
43 notarize
44 publish alpha
45 research ARM64 Wine/FEX backend
```

---

# 123. 中止条件

次の場合は力技で先へ進まずissue化する。

```text
unknown YMM4 architecture
unknown .NET deployment
unidentified crash
corrupt project file
Wine patch without reproducer
D3D output differs from Windows with unknown cause
unknown plugin ABI
unknown frame format
unknown licensing status
```

---

# 124. 最重要の設計思想

YMM4Mは、

```text
Wineを利用してWindowsを全部再現する
```

プロジェクトではない。

また、

```text
Mac版YMM4を作り直す
```

プロジェクトでもない。

理想構成は、

```text
                   ┌─ WPF correctness profile
                   │
Original YMM4 ─ Wine ─ D3D compatibility
       │           │
       │           ├─ minimal generic Wine fixes
       │           │
       │           └─ DXMT where beneficial
       │
       └─ Official plugin API
                │
                ▼
           YMM4MBridge
                │
                ▼
         ARM64 Native Host
                │
        ┌───────┴────────┐
        ▼                ▼
     FFmpeg         VideoToolbox
```

である。

---

# 125. 最終技術判断

2026年8月24日時点では、

### 純Wine案

Core機能の実現可能性はある。

しかしWPF、WebView2、D3D12、Media Foundation、Windows外部アプリ連携の問題が残る。

**単独では不十分。**

### Wine + DXMT案

D3D11系プレビューには有望。

しかしWPF/D3D9やD3D12/WebView2を解決しない。

**重要だが万能ではない。**

### Wine +大量patch案

可能だが保守コストが大きい。

**必要な部分だけに限定。**

### Wine + Native Bridge案

公式YMM4プラグインAPIを利用してWindows依存度の高い処理をMac側へ逃がせる。

特に動画出力では公式APIから映像フレーム・音声データを受け取れることが確認できている。

**YMM4Mの本命。**

### ARM64 Wine + FEX

技術的可能性は2026年に大きく高まった。

CrossOverでは実際に動作するPreviewも公開された。

しかしupstream FEXのmacOS未対応、Wine側作業、restricted entitlementなどが残る。

**将来本命だが、現時点ではProduction基盤にしない。**

---

# 126. 最終的なv1.0構成

```text
YMM4M.app
ARM64 native
│
├── Launcher
├── Installer
├── Runtime Manager
├── Drive Mapping
├── Finder Integration
├── Diagnostics
├── Bridge Server
│
├── YMM4MEncoder
│   ├── Native FFmpeg
│   └── VideoToolbox
│
└── Runtime
    │
    ├── Production:
    │   x86_64 Wine
    │   + Rosetta on supported macOS
    │
    ├── WPF:
    │   software baseline
    │   + Vulkan candidate
    │
    ├── D3D11:
    │   WineD3D baseline
    │   + pinned DXMT
    │
    └── Experimental:
        D3D12
        WebView2 workarounds
        ARM64 Wine/FEX

Inside Wine:
│
├── Original YMM4
└── YMM4MBridge.dll
```

---

# 127. プロジェクト成功条件

YMM4Mが成功したと言えるのは、

> Apple Silicon Mac利用者がWindowsをインストールせず、YMM4M.appから公式YMM4を起動し、日本語で普通に編集し、一般的な素材を利用し、プロジェクトを保存・再編集し、完成動画を書き出せる

状態になったとき。

「exeが起動した」

では成功ではない。

「一つの動画を書き出せた」

でもまだ成功ではない。

**編集ワークフロー全体の再現性が成功条件である。**

---

# 128. 最初の開発ゴール

まず、

```text
YMM4 v4.55.1.1
+
fresh Wine prefix
+
correct .NET deployment
+
WPF software rendering
```

で、

```text
起動
↓
日本語表示
↓
日本語入力
↓
PNG配置
↓
テキスト配置
↓
WAV配置
↓
プレビュー
↓
保存
↓
終了
↓
再起動
↓
再読込
```

を完全に成功させる。

ここまで到達したら、

```text
git tag milestone-core-workflow
```

を作成する。

その後、

```text
MP4
↓
D3D11 effects
↓
DXMT
↓
software export
↓
YMM4MBridge
↓
native export
↓
TTS
↓
plugins
↓
ARM64 runtime
```

の順に進む。

この順序を崩さないこと。

---

# 129. 最終命令

このプロジェクトでは、

**最新技術を使うことより、根拠を持って動作させることを優先する。**

Wine 11.16が新しくても11.0の方がYMM4に安定するなら11.0を選ぶ。

DXMTが高速でもWineD3Dの方が正しい絵を出すならWineD3Dを選ぶ。

GPU処理が壊れるなら最初はCPUを選ぶ。

Windows API互換を何か月も実装するより、YMM4公式プラグインAPIで安全にMacネイティブ処理へ逃がせるならBridgeを選ぶ。

そして、

```text
Observation
→ Evidence
→ Reproducer
→ Comparison
→ Fix
→ Regression Test
→ Documentation
→ Commit
```

の順番を常に守ること。

YMM4Mは「Wineを雑に包んだアプリ」ではなく、

**YMM4という一つのWindowsアプリケーションをMac上で実用レベルまで互換化する、検証可能かつ保守可能な専用ランタイム**

として開発すること。