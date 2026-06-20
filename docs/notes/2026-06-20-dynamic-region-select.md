# 地域ドロップダウンの動的生成への移行

## 要約

`stations.json` にリージョンを追加しても `index.html` の `<select>` に反映されない
二重管理問題を発見した．`app.rb` 起動時に `StationDirectory#regions` /
`#region_name` を使ってドロップダウンを動的生成する方針に変更した．
あわせて，Ruby.wasm で `nil` を JS プロパティに代入すると `"null"` 等の文字列が
現れる場合があることを Gemini レビューで学んだ．

## 目次

- [背景](#背景)
- [判断](#判断)
- [代替案と棄却理由](#代替案と棄却理由)
- [Ruby.wasm の nil 代入に関する注意](#rubywasm-の-nil-代入に関する注意)
- [参照](#参照)

## 背景

江別市野幌でのデモに向け， `stations.json` に `nopporo` リージョンを追加した（PR #42）．
しかし地域ドロップダウン（`<select id="region">`）の選択肢は `index.html` に
ハードコードされており，追加後も UI に野幌が表示されなかった．

`StationDirectory` クラスには `regions` メソッドが既に実装されており，
JSON のキーを返せる状態だった．`app.rb` がこのメソッドを使ってドロップダウンを
構築する実装がなく，データと UI が二重管理になっていた．

## 判断

`app.rb` 起動時（`directory` 確定直後）に `directory.regions.each` でオプションを
動的生成する．表示名は `StationDirectory#region_name(key)` から取得し，
`nil` の場合は `key` をフォールバックとして使う．

```ruby
directory.regions.each do |key|
  opt = document.call(:createElement, "option")
  opt[:value]       = key
  opt[:textContent] = directory.region_name(key) || key
  region_select_el.call(:appendChild, opt)
end
```

これにより `stations.json` へのリージョン追加だけで UI に反映されるようになった．
`index.html` の手動更新は不要になった．

## 代替案と棄却理由

表 1．検討した代替案と棄却理由．

| 代替案 | 棄却理由 |
|---|---|
| `index.html` に手動でオプションを追加する | リージョン追加のたびに 2 ファイルの更新が必要で，今回と同じ漏れが再発する |
| JavaScript 側でフェッチして DOM を構築する | Ruby.wasm 側でフェッチした結果を再利用できる．JS の追加は両端 Ruby の訴求を損なう |

## Ruby.wasm の nil 代入に関する注意

Ruby.wasm の JS 相互運用で，`nil` を JS プロパティに代入すると挙動が不定になる場合がある．
`"null"` や `"undefined"` として表示されることがあり，空文字になるとは限らない．
この挙動は Gemini レビューで指摘を受けて発覚した．

`nil` が返りうる値を JS プロパティへ代入する際は，
`|| フォールバック値` か `.to_s` で文字列化してから渡すこと．

## 参照

- [PR #42: 野幌（江別市）の局データ追加](https://github.com/tomio2480/picoruby-tea5767/pull/42)
- [PR #43: 地域ドロップダウンの動的生成](https://github.com/tomio2480/picoruby-tea5767/pull/43)
- [web/app.rb](../../web/app.rb)
- [web/lib/station_directory.rb](../../web/lib/station_directory.rb)
