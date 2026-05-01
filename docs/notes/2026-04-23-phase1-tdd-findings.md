# Phase 1 の TDD 振り返り

## 背景

Phase 1 として `web/` 下の純ロジック 4 本（Aggregator / Protocol / PeakDetector / StationDirectory）を TDD で実装した．結果は 54 tests / 69 assertions 緑．この値は PR #3 レビュー対応（Aggregator drop 追跡・初期化ガード，Protocol 型検証・String ガード，StationDirectory の Hz 単位比較）を含む．この過程で得た技術判断と運用知見を記録する．

## Ruby / minitest 環境の確認結果

- **Ruby 4.0.3**（PRISM parser, x64-mingw-ucrt）で動作確認．
- **minitest 6.0.0** が標準添付．追加 gem 不要．
- **rake 13.3.1** も同梱．`Rake::TestTask` が `spec/*_test.rb` を拾う形で問題なく動作．
- Bash からは `export PATH="/c/Ruby40-x64/bin:$PATH"` を先頭に付けて実行する必要があった．Claude Code のツールセッションが古い PATH をキャッシュしているためである．VS Code のターミナルや新規 PowerShell では PATH が自動で通る．
- 日本語のテストメソッド名（`def test_ピクセル数が...`）は minitest でそのまま通る．検索性を優先するなら Ascii 化も検討だが，v0.1 では可読性を優先した．

## TDD サイクルの運用実績

| 指標 | 値 |
|---|---|
| 1 コミットあたりの単位 | 1 クラス分（テスト＋実装＋必要なら Rakefile） |
| 1 クラスあたりのテストケース数 | 5〜10 件 |
| 1 クラスあたりの所要サイクル | Red → Green の 1 回．Refactor は発生せず |
| 全体 | 4 クラス + 初期コミット = 5 コミット |

Refactor が発生しなかった理由は，README に十分なスケルトンがあり，最初の実装で KISS な状態に収まったため．仕様が曖昧なままテストから書き始めていたら，もう少しサイクルが回った可能性もある．

## 設計上の小さな判断

### Array#max が nil を返すケースへの対処（Aggregator）

当初 README スケルトンには `@rssi[ch_start...ch_end].max || 0` と書かれていた．しかし直前で `ch_end = ch_start + 1 if ch_end <= ch_start` のガードを入れているため，スライスは常に 1 要素以上になる．`|| 0` は実際には発動しない防御コードで，Defensive Programming のコストが可読性を下回ると判断して削除した．

### `@data.dig(...) || []` と `fetch(...)` の使い分け（StationDirectory）

- `stations(region_key)` は `@data.dig("regions", region_key, "stations") || []` とした．未登録地域を静かに扱いたく，UI 側で分岐が減る．
- `regions` は `@data.fetch("regions").keys` にした．設定ファイル構造が壊れている場合は Fail Fast で早期失敗させる意図．

同じオブジェクトに対して「利用者の操作ミス（地域未登録）」と「データ構造の破損」を区別する．前者は呼び出し側の責務，後者は設定ファイルの責務．

### `module_function` を採用した理由（Protocol / PeakDetector）

ステートレスな純関数は，意図を伝えるために `class` ではなく `module module_function` を選択した．`PeakDetector.pick_max` のような内部ヘルパは `private_module_function` で隠蔽する選択肢もあったが，KISS の観点で公開したまま．将来テストから直接呼びたくなる可能性も含めて開けておく方が手間を増やさない．

### Hz 単位で ± 50 kHz 境界を判定（StationDirectory）

許容判定の基準は **「目標周波数との Hz 差が 50,000 以下ならヒット」** ．比較は Hz 同士で直接行う．

当初は `freq_hz / 1_000` で kHz に切り捨ててから比較する実装だった．この形では 50.001〜50.999 kHz のズレが切り捨て後の差 50 として誤ヒット扱いになる（PR #3 レビューで指摘）．Phase 0 で確立した「意図は結果で書く」原則と同じく，演算手段（整数除算）でなく結果（Hz 差）を基準に置く．

### テストで日本語メソッド名を採用した効果

- rake test の結果に日本語メソッド名は出ないので，実害はゼロ．
- メソッド名がそのままテスト意図の記述になり，コメント節約．
- 将来 CI に乗せた段階でレポート表示を調整したくなったら英語化も検討．

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| RSpec を採用 | minitest 標準添付で十分．gem の導入コスト・起動速度・依存を増やさない |
| テストを `test/` ディレクトリに配置（minitest 公式慣習） | README で `spec/` と明記済．RSpec 風の見た目を尊重した |
| PeakDetector をクラス化（`new(threshold:).detect(...)`） | ステートレスなので `Module.detect(..., threshold:)` で十分．KISS |
| `station_directory.rb` で実ファイル（`web/data/stations.json`）を直接参照 | ユニットテストの独立性を優先してフィクスチャで注入する設計．実データの整合性は別途統合テストで見る |

## 今後への示唆

- Phase 2 のブラウザ側（Ruby.wasm + Canvas）は自動テスト化が難しい．**純ロジックを CRuby で先に固めたので統合時のバグは描画層に絞れる** はず．
- `mock_source.rb` は「擬似 tick を生成するロジック部分」と「JavaScript の `setTimeout` で流す部分」に分離する．こうするとロジック部分だけは CRuby で minitest できる．Phase 2 でも TDD のリズムを継続できる設計を意識したい．
- `stations.json` が肥大化する将来に備え，統合テスト（実 JSON を読ませて `StationDirectory` が破綻しないかの smoke テスト）を追加するタイミングを検討．

## 参照

- [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md) 実装マイルストーン節・テスト戦略節
- 関連コミット
  - `7ce4316` 初期コミット
  - `e5b58d0` Aggregator
  - `cd61688` Protocol
  - `0a49fbb` PeakDetector
  - `d914edb` StationDirectory
- [web/lib/](../../web/lib/) / [web/spec/](../../web/spec/) / [web/Rakefile](../../web/Rakefile)