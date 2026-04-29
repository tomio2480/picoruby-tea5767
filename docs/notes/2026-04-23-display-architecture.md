# 表示手段と両端 Ruby 化の採用

## 背景

- 当初 SSD1306 OLED を Pico の I2C バスに並列接続してスペクトラム表示する計画だった．
- 実際には SSD1306 を所持していないことが判明．表示は PC 側で行う必要がある．
- デモは RubyKaigi（函館開催）を想定している．ソース公開時に「両端 Ruby で通っている」構図を取りたい．

## 判断

PC ブラウザ上で Web Serial API 経由で Pico の出力を受け取る． **Ruby.wasm（Ruby 4.0 系）** で Canvas に描画する構成を採用する．

- Pico 側は USB CDC に JSON Lines を書き出すだけ．PicoRuby で実装する．
- ブラウザ側は Ruby.wasm．ブートストラップだけ JavaScript で書き，それ以外のロジック・描画は Ruby で書く．
- 配信は GitHub Pages（HTTPS）を想定．ローカル開発は `http://localhost` を前提とする．`file://` は外部 `.rb` 読み込みで CORS により失敗する．

## 代替案と棄却理由

| 案 | 棄却理由 |
|---|---|
| Python + matplotlib（pyserial） | ランタイム依存が重く配布が面倒．RubyKaigi の訴求と噛み合わない |
| CSV + gnuplot / Excel | リアルタイム描画に別途工夫が必要 |
| Pico W + WebSocket / HTTP | Pico W の買い足しが必要 |
| SSD1306 を買い足す | 手持ち機材で完結できる構成に劣る．表示自由度も低い |
| JavaScript でブラウザ実装 | 「両端 Ruby」の訴求を損なう．敢えて採らない |

## 制約事項

- Web Serial は Chrome 系（Chrome / Edge / Opera）限定．Firefox / Safari は不可．
- Secure Context が必須．ローカルは `http://localhost`，配信は HTTPS を利用する．
- ruby.wasm の初期ロードは 3–5 秒程度．デモ前に事前ロードが必要．

## 参照

- [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md) 要約・システム全体像節
- ruby.wasm: https://github.com/ruby/ruby.wasm
- Web Serial API 仕様（WICG）: https://wicg.github.io/serial/
- Ruby 4.0.0 リリース情報: https://www.ruby-lang.org/en/news/2025/12/25/ruby-4-0-0-released/
