# Phase 1 総括: web 純ロジック 4 本の TDD 実装

## 要約

Phase 1 では `web/` 配下の純ロジック 4 本を minitest で TDD 実装した．
対象クラスは `Aggregator`， `Protocol`， `PeakDetector`， `StationDirectory` の 4 つ．
成果は PR #3 として main にマージ済み．
Phase 2 以降のブラウザ層・実機層から共通利用される基盤が固まった．
本ノートは既存ノート群の横断サマリで，登壇資料・対外発信のたたき台として位置づける．

## 目次

- 到達点
- 実装したクラスの責務
- 主要な技術判断
- レビュー対応で得た運用知見
- Phase 2 への申し送り
- 参照

## 到達点

表 1. Phase 1 の到達点．

| 項目 | 値 |
|---|---|
| 関連 PR | [#3](https://github.com/tomio2480/picoruby-tea5767/pull/3) |
| マージコミット | `40896a02` |
| ベースコミット | 5 コミット（クラス 4 本 + 初期コミット） |
| レビュー対応コミット | 6 件（Aggregator drop 追跡・初期化ガード，Protocol 型検証・String ガード，StationDirectory Hz 単位比較ほか） |
| テスト | 54 tests / 69 assertions（CRuby + minitest） |
| Refactor サイクル | 0 回（Red → Green の 1 サイクルで KISS に収束） |

## 実装したクラスの責務

表 2. Phase 1 で実装した 4 本のクラスの責務．

| クラス | ファイル | 責務 |
|---|---|---|
| `Aggregator` | [web/lib/aggregator.rb](../../web/lib/aggregator.rb) | `channel_count` 個の RSSI を `pixel_count` 個の表示用配列へ集約．範囲外周波数は drop として記録 |
| `Protocol` | [web/lib/protocol.rb](../../web/lib/protocol.rb) | TEA5767 firmware の JSON Lines を `{type, payload}` にパース．非文字列・不足フィールド・型不一致は `nil` |
| `PeakDetector` | [web/lib/peak_detector.rb](../../web/lib/peak_detector.rb) | `pixels` 配列から閾値以上の極大点を抽出．ステートレス module |
| `StationDirectory` | [web/lib/station_directory.rb](../../web/lib/station_directory.rb) | 函館 5 局のプリセットと周波数マッチ．Hz 単位で ± 50 kHz 境界を判定 |

## 主要な技術判断

詳細は [2026-04-23-phase1-tdd-findings.md](2026-04-23-phase1-tdd-findings.md) を参照．要点を抜粋する．

- **「意図は結果で書く」原則の継承**: `freq_hz / 1_000` の切り捨て比較ではなく Hz 同士で直接比較する形へ修正．Phase 0 で確立した原則（[2026-04-29-phase0-closeout.md](2026-04-29-phase0-closeout.md)）の延長．
- **Defensive Programming の取捨**: `Array#max` の `|| 0` フォールバックなど，事前ガードが効いていれば実行されない防御コードは可読性のために削除．
- **`module_function` 採用基準**: ステートレスな純関数は `class` ではなく `module module_function` で表現し， KISS を優先．
- **`fetch` と `dig` の使い分け**: 利用者の操作ミス（地域未登録）は `dig || []` で静かに扱い，データ構造の破損は `fetch` で Fail Fast．
- **テストで日本語メソッド名を採用**: `def test_ピクセル数が...` で minitest がそのまま通る．意図が読み取りやすく，コメントを節約できる．

## レビュー対応で得た運用知見

詳細は [2026-04-29-review-context-and-textlint-tips.md](2026-04-29-review-context-and-textlint-tips.md) を参照．Phase 1 で確定したカテゴリは次のとおり．

- **gemini-code-assist の繰り返し誤指摘**: 4 種類． Node.js LTS バージョン認識， TEA5767 レジスタビット， PicoRuby `I2C#write` splat ， 全角括弧の内側スペース提案．
  いずれも一次資料・中央規律で reject ．
- **CodeRabbit の妥当な指摘採用例**: Aggregator 初期化引数の正整数バリデーション， Protocol 文字列ガード強化，テスト網羅追加．
- **textlint の reject カテゴリ**: 表 caption ／固有名詞 ／ `prh` 誤 hit など．
  詳細は [tomio2480/github-workflows#12](https://github.com/tomio2480/github-workflows/issues/12) で根本対応中．
- **textlint ローカル検証の運用**: `prh.yml` を CWD に一時配置して実行．
  レビューに先回りして指摘を吸う．

## Phase 2 への申し送り

- `mock_source.rb` を **tick 生成のロジック層** と **`setTimeout` で流す時間軸層** に分離する．ロジック層は CRuby + minitest で TDD 可能な状態に保つ．
- `Aggregator#update(channel_index, frequency_hz, rssi)` の 3 引数シグネチャを維持．
  Phase 2 の MockStream と Phase 3 の SerialClient で共通利用する．
- `Aggregator#clear` は Phase 3 で追加（連続スキャンの tick `i==0` 受信時にリセット）．Phase 2 の単発スキャンでは不要．
- `stations.json` 肥大化時に備えて統合テスト（実 JSON で `StationDirectory` が破綻しないか）を Phase 4 までに検討．

## 参照

- 関連 PR: [picoruby-tea5767#3](https://github.com/tomio2480/picoruby-tea5767/pull/3)
- 既存ノート
  - [2026-04-23-implementation-plan.md](2026-04-23-implementation-plan.md)
  - [2026-04-23-display-architecture.md](2026-04-23-display-architecture.md)
  - [2026-04-23-phase1-tdd-findings.md](2026-04-23-phase1-tdd-findings.md)
  - [2026-04-29-phase0-closeout.md](2026-04-29-phase0-closeout.md)
  - [2026-04-29-review-context-and-textlint-tips.md](2026-04-29-review-context-and-textlint-tips.md)
- 設計書: [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md)
- 実装: [web/lib/](../../web/lib/) / [web/spec/](../../web/spec/) / [web/Rakefile](../../web/Rakefile)
