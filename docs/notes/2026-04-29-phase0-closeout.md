# Phase 0 振り返りと Phase 1 以降への申し送り

## 要約

PR #2 の merge により Phase 0（設計書 v0.1 確定）を完了する．
本ノートは Phase 0 で確定した方針・採用した原則・Phase 1 以降への申し送りを 1 ページにまとめる．
詳細はそれぞれの個別ノートへリンクする．

## 目次

- 対象範囲
- 確定した方針
- 採用した原則
- 後続フェーズへの申し送り
- 関連ノートへのインデックス

## 対象範囲

- 期間：2026-04-23 〜 2026-04-29
- 主な PR：[tomio2480/picoruby-tea5767 PR #2](https://github.com/tomio2480/picoruby-tea5767/pull/2)（feat/design-docs）
- 完了条件：設計書 v0.1・初期判断ノート・函館局プリセットを main へ取り込む

## 確定した方針

### 両端 Ruby と Web Serial の採用

- Pico 側は PicoRuby（R2P2 上）．
- ブラウザ側は Ruby.wasm（Ruby 4.0 系）で Web Serial を経由して受信．
- 当初の SSD1306 案は手持ち機材の都合で棄却．代替として PC ブラウザを表示端末とした．
- 詳細は [表示アーキテクチャノート](./2026-04-23-display-architecture.md)．

### 受信モジュールは TEA5767 単体

- 手持ち 4 個のうち 1 個を v0.1 で利用．
- スコープ外：音声再生・RDS 復号・電池駆動・スタンドアロン動作．

### 函館局プリセットの内蔵

- 函館市の局を [`web/data/stations.json`](../../web/data/stations.json) に置く．
- ワイド FM の HBC / STV は 2026-04-23 時点で函館運用を確認できないため除外．
- 詳細は [局プリセットノート](./2026-04-23-station-directory.md)．

### TDD と CRuby 互換テストの徹底

- firmware と web の純ロジックは CRuby 互換サブセットで書く．
- minitest で検証可能な形にし，I/O 境界はフェイクで分離する．
- ブラウザ描画やシリアル接続は手動確認に振り分ける．
- 詳細は [実装計画ノート](./2026-04-23-implementation-plan.md)．

### スタック PR と github-workflows v2

- 後続 4 段階（Phase 1 〜 4）と最終 cleanup を 5 本の PR に切り分け，2 系統のスタックとして並走させる（web トラック 3 本，firmware トラック 2 本）．
- レビュー基盤は composite action 形式の v2 を採用済．
- 詳細は [canary 検証ノート](./2026-04-28-canary-v2-verification.md)．

### PLL 計算は結果ベース基準

- N の選定基準は **「実周波数と目標周波数の誤差を最小にする整数」** ．
- 実装は `.round` を使う．これは線形関係のもとで同基準を実装する手段にあたる．
- 76.0 MHz は 9305 を採用（誤差 +1.6 kHz）．9304 は誤差 −6.6 kHz で基準に合わない．
- 詳細は [設計レビューログ](./2026-04-23-review-log.md) §1b §1c．

## 採用した原則

### 意図は結果で書く

コードのコメントや設計書の解説では，演算名（floor / round / ceil 等）を出発点にしない．
代わりに **「どんな結果を求めるか」** を意図として書く．
演算名は実装詳細であり，それだけを判断軸にすると方針がぶれる．

#### 経緯

PLL 分周比の選定で 9304（floor）と 9305（round）の間を一度往復した．
「整数除算で 9304 になる」は手続きの結果に依存した表現であり，意図そのものを直接示してはいなかった．
後に **「実周波数誤差が最小となる整数」** と結果ベースで言い換え，判断軸が固定された．

#### 適用先

- 数値変換・量子化・丸めの説明では「結果として何を求めているか」を 1 文で書く．
- 演算名は基準を実現する手段として後置する（例：「線形関係下では `.round` と等価」）．
- 単に「`.round` を使う」「整数除算で OK」とは書かない．
- レビュー時に「なぜその丸め方？」と問われた場合は，演算名ではなく結果基準で答える．
- 丸めだけでなく，しきい値・カット・サンプリング・エラー扱いなど離散化全般に適用できる．

### textlint レビューノイズへの態度

- 機械的な修正はそのまま採用する．意味を変える修正は文案併記でユーザー確認を仰ぐ．
- 既知の false positive はカテゴリ別 reject の慣習を [textlint 運用ノート](./2026-04-29-review-context-and-textlint-tips.md) にまとめた．
- 構造的なノイズは [tomio2480/github-workflows#14](https://github.com/tomio2480/github-workflows/issues/14) で根本対応を提案中．本フェーズではノイズ許容で進める判断とした．

## 後続フェーズへの申し送り

### Phase 1 〜 4 の着手順

- 進め方は web トラック先行・firmware トラック後続．
- 着手・レビュー・merge の順序は #3 → #4 → #6 → #5 → #7．
- git の依存構造は 2 系統に分かれている．
    - web トラック：#3 と #4 はそれぞれ main から派生して独立．#6 のみ #4 を base にスタック．
    - firmware トラック：#5 が main から派生．#7 は #5 を base にスタック．
- 親を持つ #6 と #7 は，親の merge 後に base を main へ切り替える．独立 PR（#3 / #4 / #5）は対象外．

### Phase 4 firmware で PLL 選定基準を結果ベースに揃える

- 採用基準は **「実周波数と目標周波数の誤差を最小にする整数」** ．これを満たす値が結果として現れる（76.0 MHz では 9305，誤差 +1.6 kHz）．議論経緯は [設計レビューログ](./2026-04-23-review-log.md) §1b §1c．
- 現状 `firmware/lib/tea5767.rb` の `pll_for` は整数除算（floor 等価）で，76.0 MHz では誤差 −6.6 kHz の 9304 を返し，基準を満たさない．
- 線形関係のもとで基準を実現する手段として `.round` メソッドを使う形に切り替える．演算名（floor / round / ceil）を出発点にしないこと．
- 対象は `firmware/spec/tea5767_test.rb` と `firmware/lib/tea5767.rb` ．テスト名・期待値・実装ロジック・コメントを基準ベースの表現に揃え，設計書側（README §TEA5767 の制御）と整合させる．

### caller-side textlint allowlist の取り込み

- [tomio2480/github-workflows#14](https://github.com/tomio2480/github-workflows/issues/14) の実装が merge された段階で本リポジトリ root に `.textlint-allowlist.yml` を追加する．
- 固有名詞（法令名等）と画像 alt text を allowlist 対象として登録する想定．

## 関連ノートへのインデックス

表 1: Phase 0 関連ノート

| 主題 | ファイル |
|---|---|
| 設計書 v0.1 本体 | [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md) |
| 表示アーキテクチャと Web Serial 採用 | [2026-04-23-display-architecture.md](./2026-04-23-display-architecture.md) |
| 局プリセット策定 | [2026-04-23-station-directory.md](./2026-04-23-station-directory.md) |
| 実装計画と Phase 区切り | [2026-04-23-implementation-plan.md](./2026-04-23-implementation-plan.md) |
| 設計レビュー応答と PLL 議論 | [2026-04-23-review-log.md](./2026-04-23-review-log.md) |
| github-workflows v2 canary 検証 | [2026-04-28-canary-v2-verification.md](./2026-04-28-canary-v2-verification.md) |
| レビュー応答と textlint 運用 | [2026-04-29-review-context-and-textlint-tips.md](./2026-04-29-review-context-and-textlint-tips.md) |
