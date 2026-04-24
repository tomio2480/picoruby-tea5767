# PicoRuby / R2P2 API の確定

## 背景

Phase 4 で `firmware/app.rb` を書いた時点では PicoRuby の API を想定で書いていた．ユーザから「picoruby/picoruby リポジトリに実装がある」との指摘を受け，本体コードを読んで API を確定した．結果として `firmware/lib/tea5767.rb` の I2C 呼び出しと `firmware/app.rb` の require / I2C.new 構文に修正が必要だった．

## 確定した API

### I2C

[picoruby-i2c/mrblib/i2c.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-i2c/mrblib/i2c.rb) と複数の実例から：

```ruby
class I2C
  DEFAULT_FREQUENCY = 100_000
  DEFAULT_TIMEOUT   = 500
  def initialize(unit:, frequency: DEFAULT_FREQUENCY, sda_pin: -1, scl_pin: -1, timeout: DEFAULT_TIMEOUT)
```

実例（[picoruby-ssd1306/example/ssd1306_demo.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-ssd1306/example/ssd1306_demo.rb) など）では **`sda_pin:` / `scl_pin:` を明示する**のが慣例．

```ruby
i2c = I2C.new(unit: :RP2040_I2C0, sda_pin: 4, scl_pin: 5, frequency: 100_000)
```

### I2C の write / read

本体コードを検索した結果：

- **`i2c.write(addr, b1, b2, ..., bN)`** ：可変長引数．配列を渡すと「1 つの引数」になるので注意．
  - 例：`@i2c.write(@address, 0x00, COLUMNADDR, 0, @width - 1)` （[picoruby-ssd1306/mrblib/ssd1306.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-ssd1306/mrblib/ssd1306.rb)）
- **`i2c.read(addr, n)`** ：バイト列を **String** で返す．`.bytes` で `Array[Integer]` 化するのが定型．
  - 例：`data = @i2c.read(ADDRESS, 7).bytes` （[picoruby-aht25/mrblib/aht25.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-aht25/mrblib/aht25.rb)）

### sleep_ms

`Kernel` 拡張としてグローバル関数で使える．[picoruby-machine/mrblib/machine.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-machine/mrblib/machine.rb) 内でも `sleep_ms wait_ms` の形で呼ばれている．

単位はミリ秒．秒単位の `sleep 1` も別途使える（`sleep` は標準）．

### require / require_relative

[picoruby-require/mrblib/require.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-require/mrblib/require.rb) を読むと **`Kernel#require_relative` は定義されていない** ．定義されているのは `require` と `load` のみ．

`require` のロードパス解決：

- 絶対パス（`/` 始まり）：そのパスを直接使う
- 相対パス：`$LOAD_PATH` から `.mrb` / `.rb` を探す

本プロジェクトでは**絶対パスで `require "/home/lib/tea5767"` と書く**方針を採用．`$LOAD_PATH.unshift` する方式より書き忘れが少ない．

### `/home/app.rb` 自動起動

[picoruby-shell/shell_executables/r2p2.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-shell/shell_executables/r2p2.rb) に以下の仕組み：

```ruby
if File.exist?("#{ENV['HOME']}/app.mrb")
  load "#{ENV['HOME']}/app.mrb"
elsif File.exist?("#{ENV['HOME']}/app.rb")
  puts "Loading app.rb"
  load "#{ENV['HOME']}/app.rb"
```

`ENV['HOME']` は既定で `/home` なので， **`/home/app.rb` を配置すれば R2P2 起動時に自動ロードされる** ．`app.mrb`（コンパイル済み）が優先される．

### `$stdout` / `puts`

[picoruby-r2p2/mrblib/main_task.rb](https://github.com/picoruby/picoruby/blob/master/mrbgems/picoruby-r2p2/mrblib/main_task.rb) の先頭で `STDOUT = IO.new` が呼ばれ，R2P2 の出力が CDC 0（USB 仮想シリアル）に流れる構造になっている．

`puts` も `$stdout.puts` も同じ IO に届く．**R2P2 はデュアル CDC** で，stderr 用の CDC 1 もある（`Machine.debug_puts` で出力）．

## 本プロジェクトへの反映

| 箇所 | 修正前 | 修正後 |
|---|---|---|
| `firmware/lib/tea5767.rb` `tune` | `@i2c.write(ADDRESS, bytes)` 配列渡し | `@i2c.write(ADDRESS, b1, b2, b3, b4, b5)` 可変長 |
| 同 `status` | `b = @i2c.read(ADDRESS, 5)` で Array 前提 | `b = @i2c.read(ADDRESS, 5).bytes` で String → Array |
| `firmware/spec/tea5767_test.rb` FakeI2C | write は `bytes` 配列受け / read は Array 返し | write は `*bytes` splat 受け / read は `.pack("C*")` で String 返し |
| `firmware/app.rb` require | `require_relative "lib/..."` | `require "/home/lib/..."` 絶対パス |
| `firmware/app.rb` I2C.new | `I2C.new(unit:, frequency:)` | `I2C.new(unit:, sda_pin: 4, scl_pin: 5, frequency:)` |

テストは修正後も 22 runs / 38 assertions 全緑．CRuby と PicoRuby の両対応を FakeI2C 側で吸収した．

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| `$LOAD_PATH.unshift "/home/lib"` + `require "tea5767"` | 起動時に 1 行追加が必要．絶対パスの方が書き忘れが起きにくい |
| TEA5767 内部で `@i2c.read` の戻り値型を判定して吸収 | CRuby / PicoRuby の分岐が TEA5767 に入り本質的でない．FakeI2C 側で PicoRuby 形式に合わせた |
| `write` に配列を渡す前提で picoruby-i2c 側に PR | 単に本プロジェクトを慣例に合わせる方が早い．将来 PR を送る選択肢は残す |

## 参照

- picoruby/picoruby リポジトリ（https://github.com/picoruby/picoruby）
  - mrbgems/picoruby-i2c/mrblib/i2c.rb
  - mrbgems/picoruby-i2c/example/i2c_scan.rb
  - mrbgems/picoruby-require/mrblib/require.rb
  - mrbgems/picoruby-r2p2/mrblib/main_task.rb
  - mrbgems/picoruby-shell/shell_executables/r2p2.rb
  - mrbgems/picoruby-machine/mrblib/machine.rb
  - mrbgems/picoruby-aht25/mrblib/aht25.rb（i2c.read 実例）
  - mrbgems/picoruby-ssd1306/example/ssd1306_demo.rb（I2C.new 実例）
- [firmware/lib/tea5767.rb](../../firmware/lib/tea5767.rb)
- [firmware/app.rb](../../firmware/app.rb)
- [2026-04-23-phase4-findings.md](./2026-04-23-phase4-findings.md)（Phase 4 当時の想定ベースの記録）