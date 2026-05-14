# 受信停止ボタン実装の知見

受信停止ボタン（PR #36）の実装で得た設計判断と詰まった箇所の記録．
TEA5767 の MUTE ビット実装に起因する I2C バスロックアップと，
ブラウザ側の状態管理バグを中心にまとめる．

## 目次

- [背景](#背景)
- [採用した設計](#採用した設計)
- [代替案と棄却理由](#代替案と棄却理由)
- [詰まった箇所](#詰まった箇所)
- [参照](#参照)

## 背景

スキャン後のバークリックで選局できるようになった（PR #33）が，
受信を止める手段がなかった．「受信停止ボタン → 再開はバークリック」という
要件を受けて実装した．

## 採用した設計

2 層で実装した．

- **UI 層**: `is_stopped` フラグで停止状態を管理し，ボタンの有効/無効と
  ステータス表示を制御する
- **Firmware 層**: TEA5767 の MUTE ビット（Byte 1 の bit 7）を利用して無音化する．
  再開は `TUNE` コマンドの再送で対応するため，`UNMUTE` コマンドは不要

ボタンの有効条件は「Pico 接続中 かつ 選局済み かつ 停止していない」に絞った．
モックスキャン後は `pico_client` が nil になるため，停止ボタンは無効のままになる．

## 代替案と棄却理由

**ブラウザ側のみで管理（firmware 変更なし）**

UI 上で「停止中」を表示するだけで，実際には TEA5767 から音が出続ける．
要件が「音を止める」であるため棄却した．

**TUNE コマンドで FM バンド外の周波数に tune する**

firmware 側の範囲チェックで弾かれるため実行できない．
範囲チェックを外すと他の問題が生じるため棄却した．

## 詰まった箇所

### 1. TEA5767 の MUTE 実装で I2C バスがロックアップする

**症状**: 停止ボタンを押した後，Pico がフリーズし以後のコマンドに一切応答しなくなる．
ブラウザ側は USB 接続が維持されているため「Pico 切断」を検知できず，
Web UI だけが正常に動き続ける状態になる．

**原因**: 初回実装の `mute` メソッドが PLL 値を 0 で書き込んでいた．

```ruby
# NG: PLL=0 は TEA5767 の有効な FM 周波数に対応しない
def mute
  @i2c.write(ADDRESS, 0x80, 0x00, 0b1011_0000, 0b0001_0000, 0b0000_0000)
end
```

TEA5767 に PLL=0 を送ると I2C バスがロックアップし，
PicoRuby の `@i2c.write` がタイムアウトなしで応答待ちを続けた．
PicoRuby は `rescue` を使用できないため，エラーが起きると上に伝播せず
そのままプロセスがブロックされる．

**修正**: `tune` 実行時に `@last_pll` へ値を保存し，`mute` でも同じ PLL 値を使う．

```ruby
def tune(freq_hz)
  @last_pll = self.class.pll_for(freq_hz)
  @i2c.write(ADDRESS, (@last_pll >> 8) & 0x3F, @last_pll & 0xFF, ...)
end

def mute
  @i2c.write(
    ADDRESS,
    ((@last_pll >> 8) & 0x3F) | 0x80,  # MUTE=1 ビットを OR する
    @last_pll & 0xFF,
    ...
  )
end
```

MUTE=1 は bit 7 なので `| 0x80`．bit 6 の SM（Search Mode）と混同しないこと．

**診断のポイント**: Pico が応答しないとき `on_stream_end` が発火しているかを確認する．
発火していなければ USB 接続は維持されており，Pico 側がフリーズしている可能性が高い．

### 2. `on_stream_end` で `is_scanning` をリセットしていなかった

Pico との接続が切断されたとき，`on_stream_end` は `pico_client = nil` と
`scan_pico_btn[:disabled] = true` は行っていたが，`is_scanning = false` を
していなかった．

結果として，切断後も `is_scanning = true` が残り，以後の `canvas.click` が
`next if is_scanning` で早期 return し続けた．
バーをクリックしても「状態が変わらない」に見えるバグだった．

修正: `on_stream_end` に `is_scanning = false` と `stop_btn[:disabled] = true` を追加した．

### 3. スキャン開始時に `stop_btn` を無効化していなかった

選局後に再スキャンを実行すると，スキャン中でも停止ボタンが有効なままだった．
スキャン開始ハンドラ（`start_mock_btn.click` / `scan_pico_btn.click`）と
`on_stream_end` のそれぞれに `stop_btn[:disabled] = true` を追加した．

## 参照

- PR #36: https://github.com/tomio2480/picoruby-tea5767/pull/36
- Issue #35: https://github.com/tomio2480/picoruby-tea5767/issues/35
- TEA5767 データシート: Write mode Byte 1 の bit 7 が MUTE，bit 6 が SM（Search Mode）
