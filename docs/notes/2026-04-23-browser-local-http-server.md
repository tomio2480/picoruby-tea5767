# ブラウザでの動作確認は HTTP サーバ経由にする

## 背景

ruby.wasm の `browser.script.iife.js` は `<script type="text/ruby" src="...">` で外部 `.rb` を読み込む機能を持つ．しかし `file://` プロトコルで `index.html` を直接開くと， CORS ポリシーにより外部ファイルの fetch が禁止されて読み込みに失敗する．

実際に出たエラー（Edge 開発者ツール）：

```
Access to fetch at 'file:///.../lib/canvas_renderer.rb' from origin 'null'
has been blocked by CORS policy: Cross origin requests are only supported for
protocol schemes: chrome-extension, chrome-untrusted, data, edge, http, https, isolated-app.
```

`browser.script.iife.js` 内部での fetch も同じエラーで停止し，Ruby.wasm の IIFE が以降の処理に進まなくなる．

## 判断

**ローカル開発時は Ruby 標準の `-run -e httpd` で簡易 HTTP サーバを起動し，`http://localhost:8000/` で開く**運用に統一する．

```powershell
cd web
ruby -run -e httpd -- . -p 8000
```

- 外部 `.rb` ファイルの fetch が CORS を通過する．
- Web Serial API の Secure Context 要件は `http://localhost` を Secure とみなすため同時に満たせる．
  Phase 3 以降の実機接続テストにもそのまま使える．
- 本番配信（GitHub Pages / HTTPS）との挙動差が小さい．

## 代替案と棄却理由

| 代替案 | 棄却理由 |
|---|---|
| 全コードをインライン `<script type="text/ruby">` に書き切る | ファイル分割が維持できない．`web/spec/` の minitest で使う `require_relative` との乖離が大きく，保守が難しい． |
| ruby.wasm 独自の VFS にファイルを埋め込む | ビルドパイプラインが必要．YAGNI に反する． |
| `--allow-file-access-from-files` 等のブラウザ起動フラグ | セキュリティ設定の変更で再現性に欠ける．他端末で動かない． |

## 参照

- [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md) リスク節（Web Serial の Secure Context 要件）
- [web/index.html](../../web/index.html)
- ruby.wasm CDN ディレクトリ: https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi/dist/
