# レビュー対応の運用知見

PR #5 と PR #6 のレビュー対応を通じて得た運用上の知見をまとめる．次回以降のレビュー対応で再現性を担保し，同じ取りこぼし・誤判定を防ぐことが目的である．

## 目次

- [1. レビュー対応の標準フロー](#1-レビュー対応の標準フロー)
- [2. 注意ポイント](#2-注意ポイント)
  - [2.1 リスト系 API は `--paginate` 必須](#21-リスト系-api-は---paginate-必須)
  - [2.2 reviewdog の position-based コメントは push で outdated 化する](#22-reviewdog-の-position-based-コメントは-push-で-outdated-化する)
  - [2.3 強調マーカー前後の半角スペースは textlint より優先](#23-強調マーカー前後の半角スペースは-textlint-より優先)
  - [2.4 stacked PR の親をマージするときは `--delete-branch` 必須](#24-stacked-pr-の親をマージするときは---delete-branch-必須)
- [3. 今回セッションで起きた具体例](#3-今回セッションで起きた具体例)
- [4. 参照](#4-参照)

## 1. レビュー対応の標準フロー

レビュー対応は次の 5 段で進める．各段で取りこぼしやすい箇所は異なるため，1 段ずつ完了を確認してから次へ進む．

1. **paginate 取得** ． `gh api .../pulls/{N}/comments --paginate` で全 review comment を取得する．reviews と issues/comments も同様に paginate 付きで取る．
2. **未返信抽出** ．自分（PR 著者）の reply 先 ID 集合を作る．root コメント（`in_reply_to_id` が null）のうち集合に含まれない ID を未返信とする．
3. **採用 / reject 判定** ．本文を取得して個別に判定する．既存コミットで対応済みなら採用済み返信．スコープ外なら別 PR への参照付き reject．誤検出なら理由付き reject．
4. **コミット → push** ．採用ぶんを 1 コミットにまとめて push する．reject ぶんはコード修正なし．
5. **返信投稿** ． `gh api .../pulls/{N}/comments` に `-f body="..."` と `-F in_reply_to={comment_id}` を付けて POST する．まとめて投稿する場合はループで実行する．

各段の jq クエリ例は本リポジトリ memory の `feedback_gh_api_paginate.md` に記載した．

## 2. 注意ポイント

### 2.1 リスト系 API は `--paginate` 必須

GitHub の `/pulls/{N}/comments` などリスト系エンドポイントは **デフォルトで 30 件ずつのページング** を返す． `--paginate` を付けないと最初の 30 件しか取れず， 30 件以降は完全に見えなくなる．

レビュー件数が多い PR では特に致命的になる．本リポジトリの PR #5 と PR #6 のレビュー対応中に paginate を忘れて 6 件の未返信を見落とした．Gemini の HIGH 重要度指摘 2 件をサブエージェントの捏造と誤判定する事態にまで至った．

サブエージェントが「ID が存在しない」と報告してきた場合， **paginate ありで自分で再確認する** 規律を持つ．

### 2.2 reviewdog の position-based コメントは push で outdated 化する

reviewdog（textlint や lint 系）の inline コメントは GitHub の position 座標に紐付いている．対象行が後続の push で消えたり大きくずれたりすると， **GitHub 側で自動 outdated 化** されて API から見えなくなる．

これは「対応コミットが解消の証跡」となる仕様であり， `Parent comment not found` エラーで返信投稿に失敗した時はバグではない．コミットメッセージで採用宣言しておけば問題ない．

ただし Gemini や CodeRabbit の意味的コメントは行ずれでも残るので， reviewdog 系のみの挙動である点に注意する．

### 2.3 強調マーカー前後の半角スペースは textlint より優先

CLAUDE.md と本リポジトリの `.gemini/styleguide.md` は **「強調記法 `**` の前後に半角スペースを挟む」** と規定している．これは `**` の直後に句読点・括弧・「．」が来る場合も適用される．

textlint の `ja-spacing/ja-no-space-around-parentheses`（括弧外側へのスペース禁止）と直接衝突する．
Gemini の references にも同方針が明記されており， **強調マーカー規律が上位** で textlint 指摘は reject する．

reject 文には CLAUDE.md / styleguide.md の引用を含めて，根拠を明示するのが望ましい．

### 2.4 stacked PR の親をマージするときは `--delete-branch` 必須

stacked PR を持つ親ブランチをマージするときは **必ず `gh pr merge --delete-branch` を使う** ．

`gh pr merge --merge` （delete-branch なし）でマージし， **後から remote ブランチを手動で削除** すると， **PR が CLOSED 化** してしまう．
GitHub の自動切替（base を `main` に変更）は，merge と branch delete が同じ API 呼び出しで連続実行された場合のみ発動する．

復旧手順は次のとおり．

1. 削除した親ブランチを **直前のコミットから一時復元** する． `git push origin <hash>:refs/heads/<branch-name>` で対応できる．
2. `gh pr reopen N` でスタック先 PR を再オープンする．
3. `gh pr edit N --base main` でベースを `main` に切り替える．
4. 親ブランチを再削除する． `git push origin --delete <branch-name>` で対応できる．

## 3. 今回セッションで起きた具体例

### 3.1 paginate 漏れ

`gh api .../pulls/5/comments --jq '...'` を paginate なしで実行した．30 件以降の Gemini HIGH 重要度指摘 3 件を「存在しない」と判定した．
サブエージェントが正しく拾った ID を「捏造」と誤判定する事態にまで至った．paginate 付きで再確認したところ，さらに 3 件（ PR #6 を含む計 6 件）の未返信が見つかった．

### 3.2 reviewdog の outdated 化

textlint の sentence-length 指摘 4 件が，対象行の修正を含む push 後に API から消えた． `gh api .../replies` で `Parent comment not found` が返る．コミットメッセージで採用宣言しておいたため整合は取れた．

### 3.3 強調マーカー vs 括弧スペース衝突

Gemini が `**手段** （` のように半角スペース挿入を要求し，採用したところ， reviewdog（textlint）が逆に「括弧外側のスペースを外せ」と新規指摘してきた．CLAUDE.md / styleguide.md と Gemini が一致して挿入を要求しているため，textlint 指摘を reject で揃えた．

### 3.4 PR #7 の CLOSED 化

PR #5 を `gh pr merge --merge`（delete-branch なし）でマージした．続けて `git push origin --delete feat/phase4-firmware` でブランチを削除した．
これにより PR #7 のベースが自動切替されず CLOSED された．上記 [2.4](#24-stacked-pr-の親をマージするときは---delete-branch-必須) の手順で復旧した．

## 4. 参照

- 本リポジトリ Claude memory（git 管理外）に 4 件のフィードバックを記録済み．
  - `feedback_gh_api_paginate.md`（paginate 規律）
  - `feedback_gh_api_reply_format.md`（返信投稿エンドポイント規律）
  - `feedback_emphasis_vs_textlint_paren.md`（強調マーカー規律）
  - `feedback_stacked_pr_branch_delete.md`（stacked PR 規律）
- [.gemini/styleguide.md](../../.gemini/styleguide.md) — 本リポジトリ Gemini styleguide（強調マーカー規律の出典）
- [PR #5](https://github.com/tomio2480/picoruby-tea5767/pull/5) — Phase 4 firmware（merged: 4af34740）
- [PR #6](https://github.com/tomio2480/picoruby-tea5767/pull/6) — Phase 3 web serial（merged: 648c6670）
- [PR #7](https://github.com/tomio2480/picoruby-tea5767/pull/7) — Phase 4.5 PicoRuby 実機 API 確定（reopen 後）
