# 実装順序: Phase 1〜5 と TDD 方針

## 背景

実機（Pico + TEA5767）接続の準備が必要なこと，および「レイヤーの高い側から作成し，まずはモックで動作確認したい」というユーザー方針を受けて，段階的な実装計画を立てる．

## 判断

次の 5 フェーズで進める．高レイヤー側から始めてモック駆動で描画まで確認し，最後に実機（Pico）接続を行う．

| 段階 | 内容 | 完了条件 |
|---|---|---|
| Phase 1 | web 純ロジックの TDD | `aggregator` / `protocol` / `peak_detector` / `station_directory` の minitest が緑 |
| Phase 2 | ブラウザ描画＋モックソース | `mock_source` で擬似 tick を流して Canvas にバーグラフと局名が描ける |
| Phase 3 | Web Serial 接続 | 実 Pico または USB CDC 相当装置から受けた JSON Lines で描画できる |
| Phase 4 | firmware 実装 | Pico 実機で 191 ch スイープと JSON Lines 出力が成立 |
| Phase 5 | 函館での実測 | RubyKaigi 会場で既知局と可視化結果が一致 |

### TDD の進め方

t_wada 氏提唱のテストファースト TDD を徹底する．

- Red → Green → Refactor の 1 サイクルで 1 コミットを目安
- テストを通すためだけにテストを修正したり仕様を変更することは禁止
- テストフレームワークは **minitest** （Ruby 4.0 系に標準添付．追加 gem 不要）

### 検証範囲

| 層 | 検証手段 |
|---|---|
| web 純ロジック（`aggregator.rb` / `protocol.rb` / `peak_detector.rb` / `station_directory.rb`） | CRuby + minitest |
| web 描画（`canvas_renderer.rb`） | ブラウザで手動確認．自動化は過剰 |
| web シリアル（`serial_client.rb`） | 実機 Pico または同等装置で確認 |
| firmware ドライバ（`tea5767.rb`） | CRuby + フェイク I2C |
| firmware ドメイン（`spectrum_scanner.rb`） | CRuby + フェイク受信機 |

## 代替案と棄却理由

| 案 | 棄却理由 |
|---|---|
| 順 A: PicoRuby 側 TDD から着手 | 実機接続の準備が必要で着手遅延．純ロジックが先にあった方が実機接続時の切り分けも楽 |
| 順 C: 設計書確定後に着手 | 実装しながらでないと細部が決めきれない．設計書も実装で固まった部分を随時反映したほうがズレがない |
| RSpec 採用 | minitest が標準添付で十分．gem 追加を避けて起動を軽くする |

## Ruby 環境の方針

- ブラウザ側（ruby.wasm）は **Ruby 4.0 系の nightly パッケージ** を採用．安定版として ruby.wasm 2.9.4 に 4.0 が含まれていないが，nightly ビルドが利用可能．
- 書くコードは **3.4 でも 4.0 でも動く範囲** に留め，`Namespace` 等の 4.0 固有機能には依存しない．これによりデモ直前の緊急退避（3.4 系への切り戻し）が `<script src=...>` 1 行の差し替えで済む．
- ローカル CRuby は **Ruby 4.0 系** をインストールして minitest を走らせる．scoop の main bucket で 4.0.1-1 が配布されている．

## 参照

- [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md) 実装マイルストーン節・テスト戦略節
- ruby.wasm: https://github.com/ruby/ruby.wasm
- t_wada の TDD 紹介: https://speakerdeck.com/twada （参考）
