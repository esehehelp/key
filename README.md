# CH32X035 12キー USB キーパッド

`key.kicad_sch` の 4 行 × 3 列スイッチを読み取り、USB **HID Boot Keyboard** として入力するファームウェアです。CDC シリアルも複合デバイスのまま残し、参照実装と同じ 1200 bps touch → BootROM 書き込みを使用します。スケッチは `firmware/keypad/keypad.ino`、ボードパッケージは `hardware/key/ch32x035f7p6/` です。

## 配線とキー

| | col1 PA0 | col2 PA1 | col3 PA2 |
|---|---|---|---|
| row1 PA3 | SW1: 0 | SW5: 1 | SW9: 2 |
| row2 PA4 | SW2: 3 | SW6: 4 | SW10: 5 |
| row3 PA5 | SW3: 6 | SW7: 7 | SW11: 8 |
| row4 PA6 | SW4: 9 | SW8: A | SW12: B |

列は順番に LOW 駆動し、非選択列は高インピーダンス、行はプルアップ入力です。ダイオードは行側がアノード・列側がカソード。約 5 ms のデバウンス、最大 6 キー同時押し、8 byte Boot Keyboard レポートを使用します。0–9 は NumLock に依存しない通常の数字キー、A/B は英字キーです（大文字になるかはホストの Shift/Caps Lock 次第）。配列 `keys` を変更すれば HID Usage を変更できます。PC3 は操作しません。回路図では LED のカソードが VDD 側で逆方向のため、ソフトウェアだけでは点灯できません。PC18/19 の SWD、PC14–17 の USB には触れません。SW40 は USB D+ 側の回路、SW41 はリセットであり、キー配列には含みません。

## Arduino IDE / CLI

このリポジトリのボードパッケージは [ch32x035f7p6-micro-devboard](../ch32x035f7p6-micro-devboard) の Arduino コア・起動処理・GPIO・USB CDC・アップロードツールをコピーしたものです。**HID 複合デバイス対応だけ** `cores/arduino/ch32x_cdc.c` を拡張しています。通常の Micro Devboard ボードではなく、必ず **CH32X035F7P6 Keypad** を選択してください (FQBN `key:ch32x035f7p6:ch32x035f7p6`)。スケッチは追加の `.h` に依存せず、HID 送信関数を `.ino` 内で宣言します。ただし実装はこのボードコアにあるため、未導入ならこのリポジトリのボードパッケージをインストールしてください。USB ID は参照 CDC 専用版の 1A86:FE0C と区別して **1A86:FE0D** です（試作用 ID。製品化時は正規の VID/PID に変更すること）。

### Windows

1. 参照リポジトリのツールチェイン・wchisp・WCH ISP ドライバをインストールします。参照 README に残っている `fix/usb-c-pd-cdc-stability` は **削除済みのブランチ** なので使わないでください。参照リポジトリを持っていればその `setup.bat` を実行します。持っていなければ PowerShell で次を実行します（旧版 `install.ps1` が残っていても上書きされます）。

   ```powershell
   curl.exe -fL https://raw.githubusercontent.com/esehehelp/ch32x035f7p6-micro-devboard/main/install.ps1 -o install.ps1
   if ($LASTEXITCODE -ne 0) { throw 'Download failed' }
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Ref main
   ```
2. このリポジトリの **`setup.bat` をダブルクリック**します（`.ps1` のダブルクリックは Windows では実行されず、編集画面が開くことがあります）。完了/失敗の表示が出るまでウィンドウを閉じないでください。スケッチブックが標準パス以外なら `setup.bat -Sketchbook D:\Arduino` をコマンドプロンプトから実行します。既存の参照ボードが別の場所にあるなら `setup.bat -ToolsFrom D:\path\to\ch32x035f7p6` も指定できます。すでに keypad ボードへツールが導入済みならそのまま再利用します。実際のインストール先と使用したツールの場所が表示されるので確認し、Arduino IDE を再起動します。
3. IDE でボード **CH32X035F7P6 Keypad** と CDC ポートを選択し、`firmware/keypad/keypad.ino` を開いて Verify / Upload します。CLI なら以下のコマンドを使えます。

### Linux

参照リポジトリの PlatformIO CH32 用 toolchain (`~/.platformio/packages/toolchain-riscv/bin`) と `wchisp` を用意し、`./install.sh` を実行します。インストール先は既定で `~/Arduino/hardware/key/ch32x035f7p6` です。別のスケッチブック・ツールチェインなら `./install.sh /path/to/sketchbook /path/to/toolchain/bin` と指定します。Python 3 と `wchisp` を PATH に配置してください。

```sh
arduino-cli compile --fqbn key:ch32x035f7p6:ch32x035f7p6 firmware/keypad
arduino-cli upload -p /dev/ttyACM0 --fqbn key:ch32x035f7p6:ch32x035f7p6 firmware/keypad
```

初回（CDC ファームウェア未書き込み）や BootROM 起動済みの場合は `-p none` でアップロードするか、参照ボードと同じ wch-link / WCH ISP の手順で初回書き込みを行ってください。実機の Arduino CLI 書き込み・検証と USB 複合デバイス列挙（cdc_acm / usbhid）を確認済みです。実キーの押下動作は未確認です。
