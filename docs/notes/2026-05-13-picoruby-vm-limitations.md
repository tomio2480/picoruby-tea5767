# PicoRuby R2P2 3.4.2 PICO ビルドの VM 制約と回避策

## 要約

実機 Pico 上で `app.rb` が動かない原因を切り分け，PicoRuby（mruby/c VM）の複数の制約を特定した．
ラムダリテラルの動的生成と，位置 + キーワード引数を混在させた呼び出しで VM 整合が崩れる．
本ドキュメントは判明した制約と診断手順，採用した回避策をまとめる．

## 目次

- 背景
- 判明した VM 制約
- 環境依存の挙動
- 診断手順
- 採用した回避策
- 残課題
- 参照

## 背景

WebSerial で Pico に接続しても JSON データが流れず，受信中のまま停止する状態が長く続いた．
DevTools と TeraTerm でブート時のメッセージを観察した．IRB により構文単位で検証して原因を絞り込んだ．

R2P2 のバージョンは 3.4.2 の PICO ビルドである．UF2 は `R2P2-PICORUBY-3.4.2-PICO-20260329-9b94521d.uf2`．

## 判明した VM 制約

### 1. ラムダリテラル `->()` の動的生成で VM が壊れる

次の代入は実行時に `Oops, return value is gone` を発生させる．

```ruby
sleeper = ->(ms) { sleep_ms(ms) }
```

メソッド呼び出しの引数位置にラムダを直書きしても同じ症状が出る．
メソッド定義の既定値 `def foo(blk = ->(_) {})` は require の時点で実体化しないため通る．
ただし呼び出し時に同じパスを通ると詰む．

### 2. 位置引数とキーワード引数を混在させた呼び出し

**位置引数とキーワード引数を混在**させた呼び出しで VM 整合が崩れる．
`SpectrumScanner.new(receiver, start_hz: ..., step_hz: ...)` がその例である．
`Oops, return value is gone` が出て戻り値が消失し，代入先が前の束縛のまま残る．

キーワード引数だけを使う呼び出しは正常に動く．
`I2C.new(unit: ..., sda_pin: ...)` や `emitter.tick(i: ..., f: ...)` がその例である．

### 3. ARYSPLAT（opcode 0x56）が未実装

`Unimplemented opcode (0x56) found (Exception)` の 0x56 は ARYSPLAT 命令に相当する．
ARYSPLAT は MRuby の `include/mruby/ops.h` で 86 番目の配列スプラット展開命令である．
コードに明示的な `*` がなくても，内部で ARYSPLAT を含むバイトコードが出る．
位置 + キーワード混在呼び出しやラムダの動的生成がその引き金となる．

### 4. rescue 修飾子の解釈差異

`expr rescue value` を IRB に打つとプロンプトが `irb>` から `irb*` に変わる．
モディファイアではなく rescue 節の開始として解釈されているためである．
ファイルに書くと `compile failed (RuntimeError)` となるケースがある．

### 5. begin/rescue/end のネストで OOM

トップレベルで `begin/rescue/end` ブロックを複数ネストすると AST ノードが急増する．
PicoRuby のコンパイラがメモリ上限を超え，`Fatal error: Out of memory.` を起こした．

## 環境依存の挙動

### MSC ドライブが認識されない

`picoruby.org` の手順では UF2 後に `R2P2` ドライブが見えるはずである．
しかし 3.4.2 PICO ビルドでは MSC が機能しなかった．`flash_nuke.uf2` で完全クリアして再インストールしても結果は同じ．

回避策は R2P2 シェル内蔵の `vim` でファイルを編集することである．
`/bin/vim` は R2P2 起動時に展開されており，TeraTerm 経由で操作できる．

### vim 流し込み時の取りこぼし

TeraTerm の「クリップボードから送信」で `.rb` を一括投入すると，
文字落ち・改行欠落によるファイル破損の事例があった．
`require` で `compile failed` が再現し，手入力で書き直すと解消した．

対策は行間遅延を 10〜30 ms に設定するか，短いファイルに分割して投入することである．

## 診断手順

長期化した試行錯誤で有効だった手順を順序で残す．

1. `flash_nuke.uf2`（Raspberry Pi 公式）でフラッシュを完全消去する．状態の蓄積を一掃できる．
2. R2P2 UF2 を再投入し，TeraTerm でブートメッセージを観察する．
3. ブート時の `Press 's' to skip` 表示中に `s` を入力する．`app.rb` の自動実行を抑止して REPL を確保する．
4. IRB に入り，疑わしい構文を **1 行ずつ** 評価する．
5. 個別には通るが require では失敗する場合は，ファイル内容の破損を疑う．
6. `Oops, return value is gone` が出たら **VM の整合崩壊** ．直前の式が原因と判定する．
7. `Unimplemented opcode (0xNN)` が出たら，MRuby の `ops.h` を参照して命令名を特定する．

## 採用した回避策

| 課題 | 回避策 |
|---|---|
| ラムダリテラル不動 | `SpectrumScanner` から `sleeper` 引数を削除し，`sleep_ms` を直接呼ぶ |
| 位置 + キーワード混在 | `SpectrumScanner#initialize` をすべて位置引数に統一 |
| begin/rescue/end の OOM | 例外処理は諦め，エラーは R2P2 の REPL に落とす |
| MSC 不在 | vim と IRB だけでファイル配置と検証を行う |
| `$stdout.sync = true rescue nil` | PicoRuby の IO に `sync=` がなく無意味のため削除 |

修正後の `firmware/lib/spectrum_scanner.rb` と `firmware/app.rb` を参照．

## 残課題

- LED フィードバックは PR #27 で対応済み．`LED_PIN = 25`・`led.write(1)`（初期化の完了後）を採用．
- 将来の PicoRuby 強化で VM 不整合は解消される見込みがある．3.4.2 が mruby/c VM の最終版で，以降は mruby VM に移行する．移行版での再評価は Issue #26 Task 3 に記録済みで，明示的な依頼があるまで保留する．
- PicoRuby upstream への報告（位置 + キーワード混在・ラムダ動的生成）は Issue #26 Task 2 に記録済みである．明示的な依頼があるまで保留する．

## 参照

- [firmware/lib/spectrum_scanner.rb](../../firmware/lib/spectrum_scanner.rb)
- [firmware/app.rb](../../firmware/app.rb)
- [picoruby/picoruby](https://github.com/picoruby/picoruby)
- [mruby/mruby の include/mruby/ops.h](https://github.com/mruby/mruby/blob/master/include/mruby/ops.h)
- [Raspberry Pi Foundation の flash_nuke.uf2](https://datasheets.raspberrypi.com/soft/flash_nuke.uf2)
- [2026-04-24-picoruby-api-confirmed.md](./2026-04-24-picoruby-api-confirmed.md)
