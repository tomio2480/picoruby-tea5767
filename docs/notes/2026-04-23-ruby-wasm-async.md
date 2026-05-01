# Ruby.wasm の await 制限と setTimeout 再帰パターン

## 背景

Ruby.wasm の `browser.script.iife.js` で `<script type="text/ruby">` を書いたとき，`JS::Object#await` を呼ぶと次のエラーが出る．

```
JS::PromiseScheduler#await: JS::Object#await can be called only from
RubyVM#evalAsync or RbValue#callAsync JS API

If you are using browser.script.iife.js, please ensure that you specify
`data-eval="async"` in your script tag
e.g. <script type="text/ruby" data-eval="async">puts :hello</script>
```

これは Ruby.wasm が **Fiber ベースで await を実装している** ために起こる．トップレベルでは `evalAsync` コンテキストが必要で，その中でしか Fiber の `yield / resume` が成立しない．

## 判断

次の 2 段階で対応する．

1. **トップレベルのスクリプトは `data-eval="async"` を必ず付ける**
   - 例：`<script type="text/ruby" data-eval="async" src="./app.rb"></script>`
   - これでスクリプト本体の `.await` が使える（fetch → JSON 読み込みなど）．
2. **`addEventListener` などのコールバック内では await を使わない**
   - コールバックは JS のイベントループから同期呼び出しされ，Fiber コンテキストの外に出る．
   - コールバック内で非同期待機が必要な場合は，**`setTimeout` の再帰呼び出し**で時間差の処理を組み立てる．

### setTimeout 再帰パターン

```ruby
class MockStream
  def run(&block)
    step = nil
    step = lambda do |i|
      if i >= rssi.size
        block.call({"t" => "done", ...})
        next
      end

      block.call({"t" => "tick", "i" => i, ...})
      JS.global.call(:setTimeout, ->() { step.call(i + 1) }, @delay_ms)
    end
    step.call(0)
  end
end
```

- `run` は即時 return する（run 本体はスケジューリングしかしない）．
- 各 tick の処理は setTimeout のコールバック内で逐次実行される．
- Ruby の Proc は `JS.global.call(:setTimeout, ...)` で自動的に JS function に変換される．

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| `Fiber.new { ... }.resume` でコールバックを手動 Fiber 化 | ruby.wasm の Fiber API を手動で扱う必要があり複雑．ドキュメントも手薄． |
| JS 側で `async` 関数を作って Ruby から呼び出す | bootstrap.js が肥大化．両端 Ruby の訴求を損なう． |
| `requestAnimationFrame` ベースで描画を駆動 | 30 ms 間隔より高頻度になりがち．191 ch × 30 ms = 約 6 秒のテンポを保ちたい今回用途に合わない． |
| コールバック全体を JS で書く | 両端 Ruby の訴求を損なう．今回採らない． |

## 開発時の動作確認チェックリスト

- [ ] HTTP サーバ経由で開いている（file:// ではない）
- [ ] すべての `<script type="text/ruby">` に `data-eval="async"` を付けている
- [ ] addEventListener のコールバック内で `.await` を呼んでいない
- [ ] `setTimeout` コールバック内の次回呼び出しは `step.call(i + 1)` のように Proc 自己参照で回している

## 参照

- [web/lib/mock_stream.rb](../../web/lib/mock_stream.rb)
- [web/app.rb](../../web/app.rb)
- [web/index.html](../../web/index.html)
- [2026-04-23-browser-local-http-server.md](./2026-04-23-browser-local-http-server.md)
- ruby.wasm エラー: `browser.script.iife.js:2771` からのメッセージ
