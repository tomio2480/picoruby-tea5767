# tomio2480/github-workflows v2 候補の canary 検証メモ

## 背景

`tomio2480/github-workflows` の v1 reusable workflow は self-detection bug
（[Issue #3](https://github.com/tomio2480/github-workflows/issues/3)）により動作しない．
代替として composite action 形式の v2 が
[PR #4](https://github.com/tomio2480/github-workflows/pull/4) で準備されている．

## 判断

picoruby-tea5767 を canary として v2 候補（commit `a342d8e4`）を pin した
caller workflow に切り替え，reviewdog の inline コメント投稿まで End-to-End
で動作することを実 PR 上で確認する．

## 代替案と棄却理由

- 中央 repo 側で別の throwaway repo を canary に使う案：既に caller として
  存在する picoruby-tea5767 を流用する方が運用コストが低く，かつ実利用環境に
  近い検証になるため不採用．

## 参照

- [tomio2480/github-workflows#3](https://github.com/tomio2480/github-workflows/issues/3)
- [tomio2480/github-workflows#4](https://github.com/tomio2480/github-workflows/pull/4)
