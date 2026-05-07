# PR #7 レビュー対応の振り返り

PR #7「PicoRuby 実機 API 確定・実機手順・ハンドオフ」で
2 ラウンドの Gemini レビューを経て得た知見を記録する．
テーマは「PicoRuby の実装不確実性への防衛コーディング」と
「ローカル textlint と CI textlint の齟齬解消」の 2 軸である．

## 目次

- [防衛コーディング：PicoRuby I/O の不確実性](#防衛コーディングpicoruby-io-の不確実性)
- [防衛コーディング：I2C 短読み取り](#防衛コーディングi2c-短読み取り)
- [Markdown 書式規律：`**` 直後スペース往復](#markdown-書式規律-直後スペース往復)
- [textlint のローカル / CI 齟齬と解消方針](#textlint-のローカル--ci-齟齬と解消方針)
- [代替案と棄却理由](#代替案と棄却理由)
- [参照](#参照)

## 防衛コーディング：PicoRuby I/O の不確実性

### 判断

`$stdout.sync = true rescue nil` を採用した．

### 背景

PicoRuby の `IO` クラスは `sync=` を実装していない可能性がある．
メソッドが存在しない場合，起動直後に `NoMethodError` でプログラムが停止する．
削除すると CRuby 環境での動作確認が困難になるため，条件分岐より
インライン `rescue nil` を選んだ．

### 適用範囲

「環境依存で実装有無が不明な初期化呼び出し」に限って `rescue nil` を許容する．
業務ロジック内のエラー握りつぶしとは区別する．

---

## 防衛コーディング：I2C 短読み取り

### 判断

`status` メソッドにガード節を追加した．

```ruby
def status
  res = @i2c.read(ADDRESS, 5)
  return { ready: false, stereo: false, rssi: 0 } if res.to_s.length < 5
  b = res.bytes
  { ... }
end
```

### 背景

通信エラーや切断時，`@i2c.read(ADDRESS, 5)` が 5 バイト未満を返すことがある．
そのとき `b[0]` が `nil` になり `NoMethodError` が発生する．
ガード節でデフォルト値を早期返却することで，スキャンループが停止しない．

### テスト追加

`FakeI2C.new(read_data: [0, 0])` で 2 バイト String を再現し，
ガード節の発火を単体テストで保証した．
24 runs / 42 assertions 全緑を維持している．

---

## Markdown 書式規律：`**` 直後スペース往復

### 判断

CLAUDE.md の規律「終了の `**` の直後に半角スペースを挟む」を最終判断とした．

### 背景

第 1 ラウンドでは textlint の「コロン前スペース不要」指摘を意識しすぎた．
その結果，`` **`i2c.write(...)`** ：`` の直後スペースを削除した．
第 2 ラウンドで Gemini が CLAUDE.md 規律違反として再指摘し，スペースを復元した．

往復が発生した原因は，`**` 直後の空白とコロン前の空白を混同したことにある．
textlint が問題とするのはコロン前の空白であり，`**` 直後の空白は対象外である．

### 教訓

CLAUDE.md の書式規律と textlint ルールが衝突して見える場合，
まず「textlint が問題とするのは何の空白か」を確認してから変更する．
CLAUDE.md 規律は最終権威であり，textlint の指摘が衝突するなら
textlint 設定の調整を先に検討する．

---

## textlint のローカル / CI 齟齬と解消方針

### 判断

ローカルの textlint 設定とパッケージをリポジトリから削除する．
以降は CI（`tomio2480/github-workflows` の Markdown Lint workflow）のみに依存する．

### 背景

ローカルと CI の textlint 設定が異なるため，複数ラウンドの往復が発生した．
「ローカル通過 → CI 落ち」または「CI 指摘修正 → ローカルに別の警告」のパターンが繰り返された．

根本原因は，中央テンプレ（`tomio2480/github-workflows`）との設定同期が
できていなかった点にある．ローカル設定が CI 設定と乖離したまま運用されていた．

### 解消手順

次セッションで以下を実施する．

1. ローカルの textlint 関連設定ファイル（`.textlintrc*`，`package.json` の
   textlint エントリ等）を削除する．
2. `node_modules` の textlint 関連パッケージを `npm uninstall` する．
   代替として `package.json` から該当エントリを除去後に `npm install` する方法もある．
3. コミットして `main` へ push する．
4. 以降は CI の結果だけを信頼して修正する．

### 注意

ローカルで構文確認したい場合は，CI と同じ設定ファイルを
`npx textlint` に明示的に渡す方法を採る．
設定なしの素の `npx textlint` は使わない．

---

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| `$stdout.sync` を `if defined?(IO) && IO.method_defined?(:sync=)` で守る | 冗長．`rescue nil` で目的を達成できる． |
| I2C エラー時に例外を raise する | スキャンループが停止する．RSSI 0 のデフォルト返却で継続する方が実機用途に合う． |
| ローカル textlint 設定を CI に合わせて更新し続ける | 中央テンプレの更新追随コストが継続発生する．削除が最も低コスト． |
| textlint 設定を中央テンプレでなく本リポジトリで管理する | 中央テンプレによる一元管理の利点を失う． |

---

## 参照

- [firmware/lib/tea5767.rb](../../firmware/lib/tea5767.rb)
- [firmware/spec/tea5767_test.rb](../../firmware/spec/tea5767_test.rb)
- [firmware/app.rb](../../firmware/app.rb)
- [docs/notes/2026-04-23-phase4-findings.md](./2026-04-23-phase4-findings.md)（Phase 4 TDD 振り返り）
- [docs/notes/2026-04-29-review-context-and-textlint-tips.md](./2026-04-29-review-context-and-textlint-tips.md)
