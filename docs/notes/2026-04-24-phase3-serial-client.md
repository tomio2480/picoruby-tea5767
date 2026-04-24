# Phase 3 Web Serial 接続の実装

## 背景

Phase 3 として `web/lib/serial_client.rb` を実装し，ブラウザから Pico の USB CDC に Web Serial API 経由で接続して JSON Lines を受信できる構造を整えた．モック / 実機切替は `app.rb` に入れ，「モックスキャン開始」と「Pico に接続」の 2 ボタンがどちらも同じハンドラで動く形にした．

## 実装上の要点

### Promise は `.call(:then)` チェインで書く

Phase 2 で確認したとおり， `JS::Object#await` は Fiber コンテキストからしか呼べない．`addEventListener` コールバックは Fiber 外なので，Web Serial API のように `requestPort → port.open → getReader → reader.read` とすべて Promise で返ってくる処理は **`.call(:then)` のチェイン** で書くしかない．

lambda の自己参照パターンで `reader.read` の Promise ループを組み立てる．

```ruby
read_next = nil
read_next = lambda do
  @reader.call(:read).call(:then) do |result|
    next if result[:done] == true
    # chunk 処理
    read_next.call
  end
end
read_next.call
```

これは Phase 2 の `MockStream` で `setTimeout` 再帰にしたパターンと同形．**「Promise を返す非同期 API を使うときは lambda 自己参照で再帰」** が今回の共通形になった．

### 行バッファリング

実機から来る `chunk` は改行区切りで届くとは限らない．`TextDecoder` で UTF-8 文字列に変換して，バッファに蓄積しつつ `"\n"` で分割する．

```ruby
while (idx = buffer.index("\n"))
  line = buffer[0...idx]
  buffer = buffer[(idx + 1)..]
  msg = Protocol.parse(line)
  block.call(msg) if msg
end
```

`Protocol.parse` は Phase 1 で TDD 済みなので再利用．行分割後の不正行は `Protocol.parse` が `nil` を返すので block.call は発火しない．

### `make_handler` lambda で UI 更新処理を共通化

`MockStream#run` と `SerialClient#run` が同じ「`msg` を yield する」契約なので，UI 更新処理を lambda にまとめて両方から使える．`aggregator` はクロージャで閉じ，ボタン押下のたびに `Aggregator.new` して handler を作り直す．

```ruby
make_handler = lambda do |aggregator|
  lambda do |msg|
    case msg["t"]
    when "tick"
      aggregator.clear if msg["i"] == 0
      aggregator.update(msg["i"], msg["rssi"])
      # ...
    when "done"
      finalize_scan.call(aggregator)
    when "error"
      scan_status_el[:textContent] = "エラー: #{msg["msg"]}"
    end
  end
end
```

### `tick.i == 0` で `Aggregator#clear`

実機は永続的に 191 ch スキャンを繰り返す．次のスキャンが始まったタイミング（tick 0 の受信）で `aggregator.clear` を挟むことで前回のバー残存を防ぐ．モック側は毎回 `Aggregator.new` されるので clear はほぼ no-op．両者で挙動が一致する．

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| Fiber ベースで `await` を使う | `addEventListener` 内から Fiber 化する API が Ruby.wasm で確立していない．複雑化リスクに見合うメリットが薄い |
| JS 側で `ReadableStream.pipeThrough(TextDecoderStream).pipeThrough(自作 LineSplitStream)` | 「両端 Ruby」訴求を損なう．行分割は Ruby で十分軽い |
| モック / 実機切替を select でまとめる | 2 ボタン並べる方がクリック 1 つで挙動が決まり UX がシンプル |
| `@reader.read` を Fiber で包んで `await` | Phase 2 と同じ理由で回避．Promise チェインで十分 |

## 開発時の動作確認チェックリスト

- [ ] `http://localhost:8000/` で開いている
- [ ] 「モックスキャン開始」で従来どおり 6 秒スキャンが動く
- [ ] 「Pico に接続」でポート選択ダイアログが出る
- [ ] 選択後に「Pico 接続済み．受信中...」と出る（実機 firmware が動いていれば）
- [ ] 拡張機能由来の Console エラーは除外して見ている（Filter `-whatsapp -chatgpt -injectAIMarker`）

## 参照

- [web/lib/serial_client.rb](../../web/lib/serial_client.rb)
- [web/app.rb](../../web/app.rb)
- [web/lib/protocol.rb](../../web/lib/protocol.rb)（行 JSON パース，Phase 1 で TDD 済み）
- [2026-04-23-ruby-wasm-async.md](./2026-04-23-ruby-wasm-async.md)（同系の非同期制約）