# YMM4 v4.56.1.0 maintenance-train evidence (2026-09-21)

実機: Apple M1 Max / macOS 27.0 / 検証済みruntime（patchset5）＋専用prefix。
YMM4M `main`＋本セッションの作業内容（`accepts()` のanchor許容、
install receiptの`.atomic`化・Eperm時のnil化）。
YMM4の導入・起動はすべて分離ストア（`~/.ymm4m-e2e/ymm4-456-store`）で行い、
オーナーの本番ストアには触れていない。

## 対象

- `YukkuriMovieMaker_v4.56.1.0.zip`（517,492,025 bytes / SHA-256
  `34b5f4c737345f1b82507381af514fc14b629f35e9ba778c25434f235fdb35cf`）
- `YukkuriMovieMaker_v4.56.1.0_Lite.zip`（515,390,353 bytes / SHA-256
  `49c0ed689f545737b7ce939971bfc625962e00791c57883dc8e6f058aa336c5a`）
- 公式provenance: `manju-summoner/YukkuriMovieMaker4` tag `v4.56.1.0`
  （stable。asset名・サイズ一致をGitHub APIで確認）。
- 注意: オーナー所持のZIPは `YukkuriMovieMaker_v4.zip` 等へリネーム済み。
  receipt検証は公式ファイル名を要求するため、内容不変のまま公式名へ
  コピーして検証した。リネーム品のままでは導入できない（仕様）。

## ランタイム境界（両editionで同一）

| File | 4.56.1.0 SHA-256 | 4.55.1 family一致 |
|---|---|---|
| YukkuriMovieMaker.runtimeconfig.json | `5ed76677…dc6c8b9`（.NET 10.0.11） | 不一致（10.0.10） |
| coreclr.dll | `c98c3078…40521` | 不一致 |
| hostfxr.dll | `44f97e94…c7bcd` | 不一致 |
| hostpolicy.dll | `ded1d42c…9cd656d` | 不一致 |
| PresentationCore.dll | `c2ac0752…19ee839` | 不一致 |
| PresentationFramework.dll | `fa9aa188…fb0cd86` | 不一致 |
| WindowsBase.dll | `42e05225…45c664e8` | 不一致 |
| System.Private.CoreLib.dll | `ed80a1a5…0706f82` | 不一致 |
| D3DCompiler_47_cor3.dll | `a05f9973…ece7ecbbb`（※4.55.1と同一hash。ファイル名の大文字小文字のみ変更） | hash一致 |

4.56系は.NET 10.0.11へ移行したため4.55.1 familyではfail-closedが正しく
働く。別family（`4.56-runtime-boundary-1`）が必要。

## 動作証拠

- 公式receipt検証（live GitHub API）: Standard/Liteとも
  version `4.56.1.0`・tag・asset名・サイズ・digest一致を確認。
- `installMaintenanceCandidate`: Standard/Liteとも成功。
  classification `maintenanceCandidate`（knownへの昇格なし）。
  再分類（receipt＋exe hash＋境界の再検証）も両版でpass。
- CLI `--help`: 両版とも正常終了（`--encode` の使用法を表示）。
- GUI: Standard 4.56.1.0のsplash→初回update確認→メインウィンドウ
  （menu・Preview・Item・timeline・台詞欄・`1920x1080 60fps 48000Hz`）を
  可視確認。Win32ServiceのMono bannerは既知のもの。
  - `evidence/ymm4-456-splash-2026-09-21.png`
  - `evidence/ymm4-456-update-check-2026-09-21.png`
  - `evidence/ymm4-456-standard-main-window-2026-09-21.png`
- rollback（Standard→Lite）: 本番rollbackパスで成功。previous保持を確認。
- Lite版GUIは未実施: 両editionのexeは同一hash（`3a2beb98…b473e9a`）であり、
  Liteの導入・再分類・rollback・CLIは検証済み。描画はexe同一のため
  Standardの証跡でカバーする。

## 副次的発見1: install receiptのmacOS 27ファイル保護問題（修正済み）

- `ymm4m-install.json` を `.completeFileProtectionUnlessOpen` で書くと、
  macOS 27ではclose後にEPERMで読めなくなる（同UID・同boot・unlock中でも
  再現。デバイスのロック状態で強制が変動する）。
- 影響: maintenance candidateの再利用・再分類・rollbackが不能になる。
  v1.0.3時点の既存receipt（4.55.1.1 Standard/Lite含む）も同様に読めない
  場合がある。known版の起動・再利用はexe hashパスのため影響なし。
- 修正: receiptのwriteを`.atomic`のみに変更（内容は公開hashのため保護不要）、
  読み失敗時はnil（＝未検証としてRecovery/警告パスへ）でfail-closed。
  契約テストに「導入直後にreceiptが読める」回帰assertを追加。
  既存の読めないreceiptは無害なまま残る（known流に影響なし）。

## 副次的発見2: `accepts()` のanchor扱い（仕様拡張）

- 従来の `candidate != tested` 条件では、新trainの起点版（4.56.1.0）自体が
  candidateとして導入不可だった（待つのは次のmicro版のみ）。
- 起点版も公式receipt＋境界＋明示確認＋previous保持の上で暫定導入できる
  よう `>=`（lexicographic）に拡張。exact-hashのknownパスが常に優先する
  ため昇格・影分類は起きない。契約テストで両方向をassert。

## 範囲の限定（何を主張しないか）

- 4.56.1.0は `maintenanceCandidate` のまま。`knownCompatible` への昇格は
  Tier A証拠が必要なため行わない。
- Tier A編集・再生・書き出し、IME直接確定、voice、可聴再生は4.56系では
  未検証。確認ダイアログの文言どおり「版固有の動作は未検証」。
- 上流にv4.56.1.1が既に存在する（4.56.1.0のupdaterが提示）。
  同一境界ならfamilyが自動で暫定候補として扱うが、導入前の確認と
  境界一致が必須のまま。

## ホストゲート（本セッションのコード変更後）

- `swift build -Xswiftc -warnings-as-errors`: pass
- `swift run YMM4MContractTests`（JA/EN両locale）: pass（新規family test含む）
- `python3 -m unittest discover -s tests/unit -p 'test_*.py'`: 32/32 pass
- `validate-runtime-lock.py` / `validate-compatibility.py` /
  `validate-bootstrap-lock.py`: pass
