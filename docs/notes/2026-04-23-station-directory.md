# 局名解決: 地域プリセット方式の採用

## 背景

スキャン結果の各ピークに **局名を表示したい** ．一般的に FM 放送では RDS（Radio Data System）の PS（Programme Service Name）で局名を電波から取得できるが，今回のプロジェクトでは以下の 2 点で RDS が使えない．

- TEA5767 には RDS デコーダが内蔵されていない（生の SCA 信号は出るが I2C から局名文字列は取れない）．
- 日本の FM 放送は RDS を運用していない．ワイド FM でも RDS は配信されない．

## 判断

**地域プリセット方式** を採用する． `web/data/stations.json` に地域ごとの局リストを static に保持し，ユーザが地域を UI で選択して周波数からプリセットを引く．

- 周波数一致の許容差は **±50 kHz** （TEA5767 の PLL 分解能を考慮）．
- `station_directory.rb` が純ロジックとして実装され，minitest で検証可能．
- v0.1 は **函館市のみ** （`regions.hakodate`）．

### 函館の初期エントリ（v0.1）

| 周波数 | 局名 | kind | 備考 |
|---|---|---|---|
| 79.4 MHz | FM NORTHWAVE | fm | 250 W |
| 80.7 MHz | FMいるか | community | 20 W．JOZZ1AA-FM |
| 83.6 MHz | NHK-FM 日浦中継局 | fm | 10 W |
| 87.0 MHz | NHK-FM 函館 | fm | 250 W．JOVK-FM |
| 88.8 MHz | AIR-G'（FM 北海道） | fm | 250 W |

HBC / STV のワイド FM は **函館では運用されていない** ため含めない．

## 代替案と棄却理由

| 案 | 棄却理由 |
|---|---|
| Si4703 / Si4705 等 RDS 対応 IC へ載せ替え | 日本では RDS が電波に載らないため効果がない．ハードを変えても局名は得られない |
| GPS 自動地域選択 | UX 複雑化．v0.1 ではスコープ外．将来拡張の余地として記録のみ |
| neighbor_stations（越境受信局を列挙） | ユーザ判断で削除．プリセット不一致の混乱を避ける |

## 構造設計のポイント

- `freq_khz` は kHz 整数で保持（浮動小数誤差を避ける）．
- `kind` で `fm` / `wide_fm` / `community` を区別．UI で色分け可能．
- `power_w` と `site` は同一周波数の複数送信地点を識別するため保持（例：FMいるか親局 20 W・日浦中継 5 W）．
- 代表エントリ 1 件＋`note` で補足する形を基本とする．

## 参照

- [picoruby-tea5767-plan/README.md](../../picoruby-tea5767-plan/README.md) 局プリセット節
- [web/data/stations.json](../../web/data/stations.json)
- 北海道函館地方 FM ラジオ周波数ガイド: https://www.denpa-data.com/i/fm/hokkaido/hakodate.htm
- 総務省 全国民放 FM 局・ワイド FM 局一覧: https://www.soumu.go.jp/menu_seisaku/ictseisaku/housou_suishin/fm-list.html
