# Phase 4 の firmware TDD 振り返り

## 背景

Phase 4 として `firmware/` 下の純ロジック 3 本（TEA5767 / SpectrumScanner / SerialEmitter）を TDD で実装した．
結果は 22 tests / 38 assertions 緑で，実機不要で設計を固め切れた．
`main.rb` は PicoRuby R2P2 想定の結線コードで CRuby テスト対象外．

## 設計上の要点

### sleeper 注入による CRuby / PicoRuby 両対応

`SpectrumScanner#initialize(..., sleeper:)` でロック待ち関数を外部注入する設計にした．

| コンテキスト | 注入する sleeper |
|---|---|
| CRuby（minitest） | `->(_ms) {}` で no-op．テストが瞬時に終わる． |
| PicoRuby 実機（main.rb） | `->(ms) { sleep_ms(ms) }` で実機 API に委譲． |

これにより `PicoRuby` 固有の `sleep_ms` への直接依存が純ロジックから消え，CRuby 上で TDD が成立する．`canvas_renderer` / `mock_stream`（web 側）でも同じパターンを採った．**「JS / PicoRuby 依存は境界で注入する」** が本プロジェクト全体の方針として定まった．

### FakeI2C / FakeReceiver は単純な属性保持で十分

```ruby
class FakeI2C
  attr_reader :last_write
  def write(address, bytes); @last_write = { address: address, bytes: bytes.dup }; end
  def read(_address, n); @read_data.first(n); end
end
```

mock gem を導入せず，`attr_reader` で記録を取って minitest のアサーションだけで検証した．テスト規模が小さいうちは軽量．

### StringIO 注入で JSON Lines 検証

`SerialEmitter#initialize(out)` で出力先を IO オブジェクトとして注入．CRuby では `StringIO.new`，実機では `$stdout`．生成された行は `@io.string.lines` で 1 行ずつ取り出して `JSON.parse` で検証する定型．

## PLL 計算の再訂正

- 76.0 MHz の PLL 期待値について，初回レビュー時に **9304 → 9305 と指摘したのが計算ミス** だった．
- Phase 4 の TEA5767 TDD 着手時に minitest が失敗して発覚．
- 正しくは `304_900_000 / 32_768 = 9304.809...` で整数除算の結果は **9304**．
- 詳細は [2026-04-23-review-log.md](./2026-04-23-review-log.md) の項 1b を参照．
- 以後，数値の訂正指摘は **二度検算する** ルールを自分に課す．

## 実機未検証ポイント

`firmware/main.rb` に以下の PicoRuby R2P2 依存 API を想定で書いた．実機で動作確認する際に要調整．

| 箇所 | 想定 | 代替候補 |
|---|---|---|
| `I2C.new(unit: :RP2040_I2C0, frequency: 100_000)` | キーワード引数形式 | 位置引数 `I2C.new(:RP2040_I2C0)` / `I2C.new(1)` などバージョン依存 |
| `require_relative "lib/..."` | R2P2 でファイル分割のまま動く | 動かない場合は結合ビルド（`r2p2 build` or 自前 concat） |
| `sleep_ms(ms)` | グローバル関数として使える | `Machine.sleep_ms(ms)` / `GPIO.sleep(...)` など別名の可能性 |
| `$stdout.puts(str)` | USB CDC に流れる | `IO.console.puts` / `puts` 直接利用 |

これらは実機焼き込み後に都度調整する．

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| `sleeper` 引数なしで `sleep_ms(ms)` を直接呼ぶ | CRuby でテスト不能．実機と 1 ファイルで統一できない． |
| `SpectrumScanner` を mrbgem 化する | YAGNI．今回は 1 ファイルで十分． |
| RSpec + mock gem を採用して I2C を stub | minitest + FakeI2C（属性記録）で十分．依存追加を避ける． |
| SerialEmitter で `printf` 直接 | JSON エスケープが面倒．`JSON.generate` を使う方が安全． |

## 参照

- [firmware/lib/tea5767.rb](../../firmware/lib/tea5767.rb) / [spec](../../firmware/spec/tea5767_test.rb)
- [firmware/lib/spectrum_scanner.rb](../../firmware/lib/spectrum_scanner.rb) / [spec](../../firmware/spec/spectrum_scanner_test.rb)
- [firmware/lib/serial_emitter.rb](../../firmware/lib/serial_emitter.rb) / [spec](../../firmware/spec/serial_emitter_test.rb)
- [firmware/main.rb](../../firmware/main.rb)
- [2026-04-23-phase1-tdd-findings.md](./2026-04-23-phase1-tdd-findings.md)（類似パターンの先行記録）