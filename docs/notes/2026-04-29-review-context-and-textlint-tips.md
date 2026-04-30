# レビュー応答と textlint 運用のコンテキスト

## 要約

過去のレビュー応答で得た知見をまとめる．
次回以降に同じ説明を繰り返さないよう，レビュアー別の典型的な指摘パターンと判断軸を残す．
本文書も中央 textlint の対象なので，書きはじめから準拠する形でまとめた．

## 目次

- レビュアー別の特徴
- 典型的な指摘と対応方針
- textlint で繰り返し直す内容
- textlint をローカルで実行する手順
- 設計書の整合性確認
- レビュー応答の運用ノウハウ
- 関連リソース

## レビュアー別の特徴

### CodeRabbit

- Ready 切替時に動く．Draft 状態では skip する
- 採用率は高め．具体的な diff 提案が付くため検証しやすい
- ファイル単位で複数の actionable comment を出す
- 過去にやり取りした学習内容を learning として保持する

### gemini-code-assist

- Ready 化後に動く．push の度に再レビューしてくる
- 同じ指摘を提案バージョンを変えて繰り返す傾向がある（Node.js v22 → v22 → v20 など）
- 採用率は中程度．事実確認が必要な指摘も混じる
- reject する場合は一次資料へのリンクを添えて根拠を明示する

### reviewdog (`textlint` / `markdownlint`)

- caller 側で composite action から呼び出される
- filter-mode: added が既定．PR 差分のみ対象
- rebase 直後は全行が added 扱いとなり，過去の lint 違反がまとめて露呈する
- 中央 prh.yml の品質にも依存する．word boundary 漏れによる誤検出がある

## 典型的な指摘と対応方針

### Node.js の LTS バージョン

- gemini が「v22 が Active LTS」「v20 が Active LTS」と主張する事例
- 2026-04-28 時点では v24 が Active LTS．v22 は Maintenance LTS．v20 は EOL 直前
- 根拠: <https://endoflife.date/nodejs>
- 対応: reject ＋ endoflife.date のリンクで反論

### TEA5767 のレジスタ設定

- gemini が「XTAL は Byte 4 の bit 6」と主張する事例
- 実際は bit 4 が XTAL．bit 6 は STBY
- 根拠: NXP / Philips の TEA5767 datasheet
- 対応: reject ＋ datasheet 引用．真理値表で PLLREF と XTAL の組み合わせも確認

### PicoRuby の `I2C#write`

- gemini が「splat 形式は ArgumentError になる」と主張する事例
- 実際は splat の Integer 列渡しが正規にサポートされている
- 根拠: picoruby-i2c の `sig/i2c.rbs`
- 対応: reject ＋ 型定義の引用．README の用例も併記する

### prh の `JS` 誤検出

- 中央 prh.yml の `JS` パターンに word boundary がない
- 結果として `JSON` 内の `JS` が substring match で誤検出される
- 対応: reject ＋ `tomio2480/github-workflows#12` を起票して根本対応

## textlint で繰り返し直す内容

### 機械的に置き換えるもの

- `ユーザ` → `ユーザー`
- `サーバ` → `サーバー`
- `レイヤ` → `レイヤー`
- `一つ` → `1 つ`（数えられるもの）
- `指定を行う` → `指定する`
- 全角かっこ前後の半角スペース除去

### 構造的に書き直すもの

- sentence-length 100 超は文を分割
- no-doubled-joshi は助詞を置換するか文を分ける
- max-kanji-continuous-len 6 超は固有名詞でない限り分割
- max-comma は 1 文 5 個以下に収める

### reject する典型例

表 1: textlint で reject 対象になる典型例

| 種別 | 理由 |
|---|---|
| 表 / 図 caption の `ja-no-mixed-period` | label 扱いで `．` を付けない慣習 |
| 画像 alt 内の sentence-length | アクセシビリティのため詳細描述を維持 |
| 固有名詞の半角全角間スペース | 固有名詞は対象外 |
| 固有名詞（法令名等）の max-kanji-continuous-len | 分解すると引用として破綻．例：電波法施行規則 |
| prh の `JS` が `JSON` の substring に hit | 中央辞書の word boundary 不備 |
| prh の `ユーザ` / `サーバ` が長音化済語の内部に hit | 中央辞書の word boundary 不備 |
| `**ラベル** ：` の構造 | 構造維持．文字レベル整形のみ |
| 全角括弧の内側へのスペース提案（gemini） | `preset-ja-spacing/ja-no-space-around-parentheses` と衝突 |

## textlint をローカルで実行する手順

PR を push する前に中央 textlint 設定と同じ違反を先取りで検出するための手順．
レビュアーへの差し戻し回数を減らせる．

### prh.yml は実行時 CWD 相対で解決される

`textlint-rule-prh` は `.textlintrc.json` の `rulePaths` を textlint 実行時の CWD から解決する．
`_tmp_lint/` のような検証用ディレクトリで実行しても，プロジェクトルートに `prh.yml` を一時配置する必要がある．

### 実行例

中央 textlint と同じ preset を `_tmp_lint/node_modules/` に置き，リポジトリルートで実行する．

```bash
cp _tmp_prh.yml prh.yml
./_tmp_lint/node_modules/.bin/textlint \
  --config _tmp_textlintrc.json \
  docs/notes/対象.md
rm -f prh.yml
```

以下の 3 つは `.gitignore` で個別に除外済み．

- `/_tmp_lint/`
- `/_tmp_prh.yml`
- `/_tmp_textlintrc.json`

新たに `_tmp_` プレフィクスのファイルを増やす場合は `.gitignore` 側にも追加する．
コピーした `prh.yml` は実行後に必ず削除する．本リポジトリには直接コミットしない．

### ローカル実行で裏取りできた reject 例

- gemini が提案する「全角括弧の内側にスペース追加」は，中央 textlint の `preset-ja-spacing/ja-no-space-around-parentheses` と衝突する．
- 元の表記（全角括弧の直内側にスペースを入れない）が中央規律と整合．Phase 1 PR #3 の L5 / L9 でこの根拠で reject した．

## 設計書の整合性確認

過去の整合性問題と教訓．

### `file://` と `http://localhost`

- README と note との間で `file://` の扱いが矛盾していた
- README が技術的事実（CORS 失敗）を記載していた
- 対応: note を README にあわせて訂正

### caller 参照の既定

- `@main` 既定と SHA pin 既定の間で方針が揺れた経緯あり
- 直近は SHA pin 既定で確定（picoruby-tea5767 PR #1 のレビューより）
- Dependabot による追随を効かせる狙いでも SHA pin が筋
- 中央テンプレも同方針で揃える

### v1 と v2 の使い分け

- v1 reusable workflow には self-detection bug がある
- v2 composite action で根本解決した
- caller workflow の構造が変わるため breaking change

## レビュー応答の運用ノウハウ

### 並列処理の活用

- textlint クリーンアップは複数ファイルにわたる
- ファイルごとにサブエージェント（Sonnet）を割り当てて並列実行できる
- 1 ファイル分でも 30〜40 件の修正対象になりうるため，並列化の効果が大きい
- 並列実行時は採用 / reject の方針を各エージェントへ明示する

### 文章書き換えの判断

- 機械的修正は私（あるいはエージェント）の裁量で進めてよい
- sentence-length / no-doubled-joshi など意味を変えうる修正は文案を提示する
- 「原文」と「修正案」を併記して，ユーザー判断を仰ぐ

### 矛盾するレビュー指摘への対応

- 同じ箇所へ異なる方向から指摘が入ることもある
  - 例: フル SHA を書け（前回）→ 80 文字超で読みにくい（今回）
- 矛盾点を明記して reject ＋過去スレッドへリンク

### 一括 reject の説明

- reviewdog の指摘が大量に出るとき個別返信は現実的でない
- top-level コメントでカテゴリ別に reject 理由をまとめると効率的
- カテゴリは prh / 表 caption / alt text / 固有名詞 / 構造維持など

## 関連リソース

- v2 release: <https://github.com/tomio2480/github-workflows/releases/tag/v2>
- prh `JS` 誤検出 issue: <https://github.com/tomio2480/github-workflows/issues/12>
- caller-side allowlist 提案 issue: <https://github.com/tomio2480/github-workflows/issues/14>
- MD013 方針 issue: <https://github.com/tomio2480/github-workflows/issues/6>
- fixture 除外 issue: <https://github.com/tomio2480/github-workflows/issues/5>
- npm pin issue: <https://github.com/tomio2480/github-workflows/issues/7>
- 中央 textlint config: <https://github.com/tomio2480/github-workflows/blob/main/templates/.textlintrc.json>
- 中央 prh 辞書: <https://github.com/tomio2480/github-workflows/blob/main/templates/prh.yml>
- グローバル CLAUDE.md スタイル: ユーザー個人の `~/.claude/CLAUDE.md`
