# クリック選局・ホバーエフェクト実装の知見

PR #33 で実装したバークリック選局・ホバーエフェクト機能の設計判断と知見をまとめる．

## 目次

- [背景](#背景)
- [Ruby クロージャの変数キャプチャ順序バグ](#ruby-クロージャの変数キャプチャ順序バグ)
- [Ruby.wasm + Canvas のイベント・座標変換パターン](#rubywasm--canvas-のイベント座標変換パターン)
- [複数ハンドラでの再描画集約パターン](#複数ハンドラでの再描画集約パターン)
- [PicoRuby コマンド拡張パターン](#picoruby-コマンド拡張パターン)
- [参照](#参照)

## 背景

スキャン後のスペクトルグラフでバーをクリックすると受信周波数を固定する機能と，
マウスオーバーでバーが色変わりするホバーエフェクトを追加した．

## Ruby クロージャの変数キャプチャ順序バグ

### 問題

Ruby では lambda / block が定義された時点でスコープ内に存在しない変数への代入は，
outer スコープを更新せずに lambda ローカル変数を生成する．

```ruby
# バグになるパターン
finalize_scan = lambda do
  last_rssi_array = rssi_array   # outer の last_rssi_array を更新しているつもりだが…
end

last_rssi_array = nil            # finalize_scan の定義より後ろで宣言 → キャプチャされない
```

`finalize_scan` 内の `last_rssi_array = rssi_array` は，outer の変数を更新せず
lambda ローカルに書き込むだけになる．`canvas.addEventListener("click")` から
`last_rssi_array` を参照しても常に `nil` のままとなりバグになる．

### 修正

変数を使う lambda より **前** で宣言する．

```ruby
last_rssi_array = nil            # finalize_scan より先に宣言
last_named_labels = nil

finalize_scan = lambda do
  last_rssi_array = rssi_array   # これで outer 変数が更新される
  ...
end
```

### 教訓

Ruby.wasm の `app.rb` は複数の lambda が互いに変数を共有する構造になりやすい．
どの変数がどの lambda からアクセスされるかを意識し，lambda 定義より前に宣言する．
セルフレビューの観点として「lambda の定義順と変数宣言順が合っているか」を確認する．

## Ruby.wasm + Canvas のイベント・座標変換パターン

### イベントオブジェクトの受け取り

```ruby
canvas.addEventListener("click") do |event|
  # event[:clientX], event[:clientY] で座標を取得できる
end
```

### CSS スケーリング補正

`canvas` の HTML 属性 `width="800"` と CSS `width: 100%; max-width: 800px;` が
異なる場合，クリック座標が Canvas ピクセル座標とずれる．
`getBoundingClientRect()` で実際の表示サイズを取得して補正する．

```ruby
rect     = canvas.call(:getBoundingClientRect)
scale    = canvas[:width].to_f / rect[:width].to_f
canvas_x = (event[:clientX].to_f - rect[:left].to_f) * scale
```

### mousemove の最適化

`mousemove` はフレームレートに近い頻度で発火するため，
hover チャンネルが変わったときのみ再描画して CPU 負荷を抑える．

```ruby
next if hover_ch == last_hover_ch
last_hover_ch = hover_ch
refresh_canvas.call
```

## 複数ハンドラでの再描画集約パターン

`click` / `mousemove` / `mouseleave` が同じ描画シーケンスを繰り返す場合，
lambda に抽出して一元管理する．

```ruby
refresh_canvas = lambda do
  renderer.clear
  renderer.draw_axis
  renderer.draw_bars(last_rssi_array, selected_ch_index, last_hover_ch)
  renderer.draw_station_labels(last_named_labels)
end
```

この集約により，`click` ハンドラが `last_hover_ch` を渡し忘れるちらつきバグも
構造的に防止できた（レビュー指摘で発覚）．

## PicoRuby コマンド拡張パターン

### SCAN から SCAN/TUNE への拡張

既存の `next unless line.strip == "SCAN"` を `case/when` に置き換えた．
PicoRuby は `rescue` が使用禁止（Unimplemented opcode 0x56）なので，
引数バリデーションは条件分岐で防御する．

```ruby
cmd   = line.strip
parts = cmd.split(":")

case parts[0]
when "SCAN"
  ...
when "TUNE"
  next if parts[1].nil?
  freq_hz = parts[1].to_i
  next if freq_hz < START_HZ || freq_hz > START_HZ + STEP_HZ * (CHANNEL_COUNT - 1)
  receiver.tune(freq_hz)
  led.write(1)
  sleep_ms(50)   # LED 点灯を視認可能な時間に保つ
  led.write(0)
end
```

`String#split` は PicoRuby で使用可能（実機確認済み）．
`.to_i` は非数値文字列に対して `0` を返すため，範囲チェックで弾ける．

## 参照

- PR #33: feat/click-to-tune
- [project_picoruby_api.md](../../.claude/projects/c--Users-tomio-Works-picoruby-tea5767/memory/project_picoruby_api.md) — PicoRuby 確認済み API と制約
