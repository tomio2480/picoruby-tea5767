# Pico 実機セットアップと動作確認手順

## 背景

Phase 5（函館実測）に向けた実機接続手順を整理する．ブラウザ側（Phase 2 / 3）と firmware 側（Phase 4）のコードが揃った段階で使う手順書である．PicoRuby R2P2 は Pico への書き込みが完了済みである前提とする（本リポジトリ対象外）．

## 前提条件

- PicoRuby R2P2 が書き込まれた Raspberry Pi Pico．
- TEA5767 モジュール（I2C アドレス 0x60）．
- USB ケーブル（Pico 用 Micro-B）と PC（Chrome または Edge）．
- 75 cm 程度のワイヤ（アンテナ）．
- ブレッドボードとジャンパ．

## 手順

### 1. 配線

[picoruby-tea5767-plan/schematic.svg](../../picoruby-tea5767-plan/schematic.svg) のとおり，4 本だけ接続する．

| Pico ピン | TEA5767 ピン |
|---|---|
| Pin 6（GP4 / SDA） | SDA |
| Pin 7（GP5 / SCL） | SCL |
| Pin 8（GND） | GND |
| Pin 36（3V3 OUT） | VCC |

TEA5767 の ANT 端子に 75 cm ワイヤを接続．L_OUT / R_OUT は v0.1 では使わない．プルアップ抵抗は TEA5767 モジュール実装のものを利用する前提．通信失敗時は 4.7 kΩ を外付けで追加．

### 2. firmware 転送

R2P2 は `/home/app.rb` を起動時に自動実行する．`firmware/app.rb` を `/home/app.rb` に，`firmware/lib/*.rb` を `/home/lib/*.rb` 以下へ配置する．転送は R2P2 のドキュメント（シェルの `cp` / DFU など）に従う．

- `app.rb` では `require "/home/lib/tea5767"` のように絶対パスで require している．PicoRuby には `require_relative` が未実装のため．
- 各 API は picoruby/picoruby 本体のコードで確認済み（[2026-04-24-picoruby-api-confirmed.md](./2026-04-24-picoruby-api-confirmed.md) 参照）．

### 3. PC に接続

- Pico を USB で PC に接続（電源供給 + USB CDC シリアル）．
- 正常に起動していれば `firmware/app.rb` が動き，LED が瞬間点灯してコマンド待ち状態に入る．JSON Lines はブラウザから "SCAN" コマンドを受け取った後にのみ出力される．
- Windows ではデバイスマネージャーで `COMx` として見える．

### 4. ブラウザで HTTP サーバーを起動

```powershell
cd "C:\path\to\your\repo\web"
ruby -run -e httpd -- . -p 8000
```

ブラウザで `http://localhost:8000/` を開き， **「Pico に接続」** ボタンを押す．
Web Serial のポート選択ダイアログが出るので Pico の COM を選ぶ．接続されると「Pico 接続済み．スキャンボタンを押してください」に切り替わる．
続けて **「スキャン実行」** ボタンを押すとスキャンが開始される．

### 5. スキャン結果の確認

- 「スキャン実行」ボタン押下後，左から右へバーが順に立ち上がる（約 10 秒で 191 ch）．
- 函館の主要局にピーク（79.4 / 80.7 / 83.6 / 87.0 / 88.8 MHz）．
- done 受信後，検出局テーブルへ 5 行が追加され，「スキャン実行」ボタンが再び有効化される．
- 次のスキャンはボタンを押すまで開始しない（自動連続スキャンはしない）．

## トラブルシューティング

| 症状 | 原因候補 | 対応 |
|---|---|---|
| ポート選択に Pico が出てこない | USB CDC が有効でない | R2P2 のビルドオプション（`CDC_ENABLE` 相当）を確認． |
| 接続エラー表示 | 他アプリが COM を占有 | Arduino IDE や TeraTerm など他のシリアル接続ツールを閉じる． |
| スキャンは届くが全 ch で RSSI=0 | I2C 通信失敗 | `i2cscan` 相当コマンドで 0x60 が見えるか確認．プルアップ抵抗の有無を確認． |
| スキャンは来るが局が検出されない | アンテナゲイン不足 | 75 cm ワイヤを垂直に伸ばす．屋外に近い窓際で再確認． |
| 特定の周波数で局名が引けない | `stations.json` と周波数のズレ | TEA5767 の PLL 分解能で ±50 kHz のズレが出得る．`station_directory.rb` の `MATCH_TOLERANCE_KHZ` を調整するか `stations.json` を実測に合わせる． |
| Console に JSON パースエラー連発 | firmware 側の出力が壊れている | `firmware/app.rb` に `$stdout.flush` を入れる．`SerialEmitter` の JSON 生成が正しいか `firmware/spec` で再確認． |
| Connect 直後に切断 | ポート競合 or 権限 | ブラウザを再起動．OS の USB 認識を確認． |

## 参照

- [picoruby-tea5767-plan/schematic.svg](../../picoruby-tea5767-plan/schematic.svg)
- [firmware/app.rb](../../firmware/app.rb)
- [web/lib/serial_client.rb](../../web/lib/serial_client.rb)
- [2026-04-23-browser-local-http-server.md](./2026-04-23-browser-local-http-server.md)
- [2026-04-24-phase3-serial-client.md](./2026-04-24-phase3-serial-client.md)
