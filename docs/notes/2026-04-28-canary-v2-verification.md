# `tomio2480/github-workflows` v2 候補の canary 検証メモ

## 背景

`tomio2480/github-workflows` の v1 reusable workflow には self-detection bug が存在する．
詳細は [Issue #3](https://github.com/tomio2480/github-workflows/issues/3) を参照．
代替として composite action 形式の v2 を [PR #4](https://github.com/tomio2480/github-workflows/pull/4) で準備した．

## 判断

picoruby-tea5767 を canary として活用する．
v2 候補 commit `a342d8e4511a3cbbe13b9a976efedfe1f2aee878` を SHA pin した caller に切り替える．
reviewdog の inline コメント投稿まで End-to-End で動作することを実 PR 上で確認する．

## 代替案と棄却理由

throwaway repo を中央側に新設する案も検討した．
ただし既存 caller である picoruby-tea5767 を流用する方が運用コストは低い．
実利用環境に近い検証も同時に得られるため，本案を採用しなかった．

## 参照

- [tomio2480/github-workflows#3](https://github.com/tomio2480/github-workflows/issues/3)
- [tomio2480/github-workflows#4](https://github.com/tomio2480/github-workflows/pull/4)
