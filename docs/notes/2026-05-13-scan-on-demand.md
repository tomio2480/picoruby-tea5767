# スキャンオンデマンド実装の知見

## 要約

- [背景](#背景)
- [$stdin.gets の動作確認（PicoRuby）](#stdingets-の動作確認picoruby)
- [USB スリープ・ウェイクの不可能性](#usb-スリープウェイクの不可能性)
- [双方向 Web Serial 設計](#双方向-web-serial-設計)
- [current_handler クロージャパターン](#current_handler-クロージャパターン)
- [LED フィードバック方針](#led-フィードバック方針)
- [レビューから得た学び](#レビューから得た学び)
- [参照](#参照)

Pico 起動後の無限スキャンを廃止し，Web UI ボタン押下時のみ 1 周スキャンを実行する制御（PR #29）の実装で得た知見をまとめる．

## 背景

Phase 5（RubyKaigi デモ）で「スキャン開始を人間が制御したい」という要件が生まれた．
従来は Pico 起動直後から無限ループでスキャンしていたため，スキャン制御を Web UI 側に移す設計変更が必要だった．

## $stdin.gets の動作確認（PicoRuby）

R2P2 IRB による実機確認結果：

```
irb> line = $stdin.gets
hello
=> "hello\r"
```

- 戻り値は `\r` 終端（`\n` ではない）．`.strip` で trim が必要．
- nil を返す条件は未確定（CDC 切断時等の可能性）．`rescue` が使えないため `next if line.nil?` で継続する．

## USB スリープ・ウェイクの不可能性

当初，コマンド待ち中のスリープと USB 割り込みによるウェイクを検討した．調査結果は次のとおり．

- `Machine.sleep`/`Machine.deep_sleep` を呼ぶと USB phy が停止する．
- USB CDC 接続が切断されるため，USB CDC 経由で割り込みをかけてウェイクすることは不可能．
- RP2040 の DORMANT モードも同様．

ブロッキング `$stdin.gets` によるコマンド待ちが唯一の選択肢となる．

## 双方向 Web Serial 設計

従来は Pico→ブラウザの一方向（JSON Lines 受信）だった．今回はブラウザ→Pico のコマンド送信を追加した．

**送信（`SerialClient#write`）:**

```ruby
def write(text)
  return if @port.nil?

  encoder = JS.global[:TextEncoder].new
  data    = encoder.call(:encode, text)
  writer  = @port[:writable].call(:getWriter)
  writer.call(:write, data).call(:then) do |_|
    writer.call(:releaseLock)
  end.call(:catch) do |_|
    writer.call(:releaseLock)
  end
end
```

`.then` と `.catch` の両方で `releaseLock` を呼ばないと writable stream がデッドロックする．

**Pico 側受信:**

```ruby
loop do
  line = $stdin.gets
  next if line.nil?
  next unless line.strip == "SCAN"
  # スキャン実行
end
```

コマンド名 `"SCAN"` はブラウザ側（`pico_client.write("SCAN\n")`）と対応させる．

## current_handler クロージャパターン

`c.run()` は Pico 接続時に 1 回だけ呼ぶ（二重 read loop 防止）．スキャンごとにハンドラを差し替えるため，可変な `current_handler` 変数を使う．

```ruby
# 接続完了時: run は 1 回だけ
c.run(on_error: on_stream_end) { |msg| current_handler&.call(msg) }

# スキャンボタン押下時: ハンドラを差し替える
current_handler = make_handler.call(aggregator, region_key, on_scan_done)
pico_client.write("SCAN\n")
```

`current_handler` のクリアタイミングは次のとおり．

| タイミング | 処理 |
|---|---|
| スキャン完了（`on_scan_done`） | `current_handler = nil` |
| スキャン前の設定エラー（`rescue`） | `current_handler = nil` |
| Pico 切断（`on_stream_end`） | `current_handler = nil` |
| 接続ボタン押下（再接続開始時） | `current_handler = nil` |

スキャン中以外に Pico から予期せぬデータが来ても `current_handler&.call` が空振りし，誤動作を防ぐ．

## LED フィードバック方針

| 状態 | LED |
|---|---|
| 初期化完了（一瞬） | 点灯 → 即消灯 |
| コマンド待ち | 消灯 |
| スキャン中 | 点灯 |
| スキャン完了 | 消灯 |

## レビューから得た学び

gemini-code-assist が NHK-FM 新北見中継局の `power_w` を 10 W と提案したが，Wikipedia「北見中継局」で 100 W（ERP 260 W）と確認でき，提案値が誤りだった．
自動レビューの指摘値は一次情報（公式サイト・Wikipedia 等）で照合してから採否を決める．

## 参照

- [firmware/app.rb](../../firmware/app.rb)
- [web/lib/serial_client.rb](../../web/lib/serial_client.rb)
- [web/app.rb](../../web/app.rb)
- [2026-04-24-picoruby-api-confirmed.md](./2026-04-24-picoruby-api-confirmed.md)
- [2026-05-13-picoruby-vm-limitations.md](./2026-05-13-picoruby-vm-limitations.md)
