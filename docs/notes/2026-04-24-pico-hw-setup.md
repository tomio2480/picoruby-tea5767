# Pico 実機セットアップと動作確認手順

## 背景

Phase 5（函館実測）に向けて，ブラウザ側（Phase 2 / 3）と firmware 側（Phase 4）のコードが揃った段階での実機接続手順を整理する．PicoRuby R2P2 は事前に Pico に書き込み済みである前提（本リポジトリ対象外）．

## 前提条件

- PicoRuby R2P2 が書き込まれた Raspberry Pi Pico
- TEA5767 モジュール（I2C アドレス 0x60）
- USB ケーブル（Pico 用 Micro-B）と PC（Chrome または Edge）
- 75 cm 程度のワイヤ（アンテナ）
- ブレッドボードとジャンパ

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

`firmware/main.rb` と `firmware/lib/*.rb` を R2P2 のファイルシステムに転送する．R2P2 のバージョンにより方式が違うので，R2P2 のドキュメントに従う．

- `require_relative` が動かない場合は，`firmware/lib/*.rb` の内容を `main.rb` の先頭に結合した 1 ファイルをアップロードして回避
- `I2C.new(unit:, frequency:)` / `sleep_ms(ms)` / `$stdout.puts` の API が R2P2 の実装と異なる場合は `main.rb` 側で調整

### 3. PC に接続

- Pico を USB で PC に接続（電源供給 + USB CDC シリアル）
- 正常に起動していれば `firmware/main.rb` が動き JSON Lines を 115200 bps で吐き続ける
- Windows ではデバイスマネージャーで `COMx` として見える

### 4. ブラウザで HTTP サーバを起動

```powershell
cd "C:\path\to\your\repo\web"
ruby -run -e httpd -- . -p 8000
```

ブラウザで `http://localhost:8000/` を開き， **「Pico に接続」** ボタンを押す．
Web Serial のポート選択ダイアログが出るので Pico の COM を選ぶ．接続されると「Pico 接続済み．受信中...」に切り替わる．

### 5. スキャン結果の確認

- 左から右へバーが順に立ち上がる（約 10 秒で 191 ch）
- 函館の主要局にピーク（79.4 / 80.7 / 83.6 / 87.0 / 88.8 MHz）
- done 受信後に検出局テーブルに 5 行並ぶ
- 実機は permanent loop なので，500 ms 後に次のスキャンが始まる（tick 0 で Canvas がリセットされる）

## トラブルシューティング

| 症状 | 原因候補 | 対応 |
|---|---|---|
| ポート選択に Pico が出てこない | USB CDC が有効でない | R2P2 のビルドオプション（`CDC_ENABLE` 相当）を確認 |
| 接続エラー表示 | 他アプリが COM を占有 | Arduino IDE や TeraTerm など他のシリアル接続ツールを閉じる |
| スキャンは届くが全 ch で RSSI=0 | I2C 通信失敗 | `i2cscan` 相当コマンドで 0x60 が見えるか確認．プルアップ抵抗の有無を確認 |
| スキャンは来るが局が検出されない | アンテナゲイン不足 | 75 cm ワイヤを垂直に伸ばす．屋外に近い窓際で再確認 |
| 特定の周波数で局名が引けない | `stations.json` と周波数のズレ | TEA5767 の PLL 分解能で ±50 kHz のズレが出得る．`station_directory.rb` の `MATCH_TOLERANCE_KHZ` を調整するか `stations.json` を実測に合わせる |
| Console に JSON パースエラー連発 | firmware 側の出力が壊れている | `firmware/main.rb` に `$stdout.flush` を入れる．`SerialEmitter` の JSON 生成が正しいか `firmware/spec` で再確認 |
| Connect 直後に切断 | ポート競合 or 権限 | ブラウザを再起動．OS の USB 認識を確認 |

## 参照

- [picoruby-tea5767-plan/schematic.svg](../../picoruby-tea5767-plan/schematic.svg)
- [firmware/main.rb](../../firmware/main.rb)
- [web/lib/serial_client.rb](../../web/lib/serial_client.rb)
- [2026-04-23-browser-local-http-server.md](./2026-04-23-browser-local-http-server.md)
- [2026-04-24-phase3-serial-client.md](./2026-04-24-phase3-serial-client.md)