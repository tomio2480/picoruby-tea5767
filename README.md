# picoruby-tea5767

PicoRuby + TEA5767 + Ruby.wasm で作る FM スペクトラムモニタ．函館での RubyKaigi デモ動作を v0.1 の到達点とする．

## 特徴

- Pico 側は **PicoRuby R2P2** で TEA5767 を I2C 制御し，USB CDC に JSON Lines を吐く
- ブラウザ側は **Ruby.wasm**（Ruby 4.0 系）で Web Serial API から受け取って Canvas に描画
- 両端が Ruby で通った構成を RubyKaigi 向けに見せる題材

## ディレクトリ構成

| 場所 | 内容 |
|---|---|
| [picoruby-tea5767-plan/](picoruby-tea5767-plan/) | 設計書．README・回路図・UI レイアウト・KiCad |
| [firmware/](firmware/) | Raspberry Pi Pico 側の PicoRuby コード |
| [web/](web/) | ブラウザ側の Ruby.wasm コード |
| [docs/notes/](docs/notes/) | 設計判断と開発知見のメモ |

## 詳細

[picoruby-tea5767-plan/README.md](picoruby-tea5767-plan/README.md) が v0.1 の正式な設計書．
実装の進め方や決定の経緯は [docs/notes/](docs/notes/) のノート群を参照．

## ライセンス

MIT．[LICENSE](LICENSE) を参照．