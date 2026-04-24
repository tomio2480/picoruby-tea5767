require "js"
require "json"

START_HZ          = 76_000_000
STEP_HZ           = 100_000
CHANNEL_COUNT     = 191
REGION            = "hakodate"
STATION_FREQS_KHZ = [79_400, 80_700, 83_600, 87_000, 88_800].freeze
PEAK_THRESHOLD    = 10

document         = JS.global[:document]
canvas           = document.getElementById("spectrum")
status_el        = document.getElementById("status")
start_mock_btn   = document.getElementById("start-mock")
connect_pico_btn = document.getElementById("connect-pico")
scan_status_el   = document.getElementById("scan-status")
peak_tbody_el    = document.getElementById("peak-tbody")

renderer = CanvasRenderer.new(
  canvas,
  start_hz:      START_HZ,
  step_hz:       STEP_HZ,
  channel_count: CHANNEL_COUNT,
)

response = JS.global.call(:fetch, "./data/stations.json").await
stations_data = JSON.parse(response.call(:text).await.to_s)
directory = StationDirectory.new(stations_data)

renderer.clear
renderer.draw_axis

status_el[:textContent] = "Ruby.wasm 起動成功: Ruby #{RUBY_VERSION}"
status_el[:className]   = "status ok"

finalize_scan = lambda do |aggregator|
  rssi_array = aggregator.pixels
  peaks = PeakDetector.detect(rssi_array, threshold: PEAK_THRESHOLD)
  named = peaks.map do |peak|
    freq_hz = START_HZ + STEP_HZ * peak[:i]
    station = directory.lookup(REGION, freq_hz)
    {
      ch_index: peak[:i],
      freq_hz:  freq_hz,
      rssi:     peak[:rssi],
      name:     station ? station["name"] : "(未登録)",
    }
  end

  renderer.clear
  renderer.draw_axis
  renderer.draw_bars(rssi_array)
  renderer.draw_station_labels(
    named.map { |p| { ch_index: p[:ch_index], name: p[:name] } }
  )

  rows = named.sort_by { |p| -p[:rssi] }.map do |p|
    mhz = format("%.1f", p[:freq_hz] / 1_000_000.0)
    "<tr><td>#{mhz} MHz</td><td>#{p[:rssi]}/15</td><td>#{p[:name]}</td></tr>"
  end.join
  peak_tbody_el[:innerHTML] = rows.empty? ? "<tr><td colspan=\"3\">検出なし</td></tr>" : rows
  scan_status_el[:textContent] = "完了 (#{named.size} 局検出)"
end

make_handler = lambda do |aggregator|
  lambda do |msg|
    case msg["t"]
    when "tick"
      aggregator.clear if msg["i"] == 0
      aggregator.update(msg["i"], msg["rssi"])
      renderer.clear
      renderer.draw_axis
      renderer.draw_bars(aggregator.pixels, msg["i"])
      scan_status_el[:textContent] = "スキャン中: #{msg["i"] + 1}/#{CHANNEL_COUNT} ch"
    when "done"
      finalize_scan.call(aggregator)
    when "error"
      scan_status_el[:textContent] = "エラー: #{msg["msg"]}"
    end
  end
end

start_mock_btn.addEventListener("click") do
  scan_status_el[:textContent] = "モックスキャン中..."
  peak_tbody_el[:innerHTML]    = "<tr><td colspan=\"3\">スキャン中...</td></tr>"

  aggregator = Aggregator.new(channel_count: CHANNEL_COUNT, pixel_count: CHANNEL_COUNT)
  source = MockSource.new(
    start_hz:          START_HZ,
    step_hz:           STEP_HZ,
    channel_count:     CHANNEL_COUNT,
    station_freqs_khz: STATION_FREQS_KHZ,
    seed:              42,
  )
  stream = MockStream.new(source, start_hz: START_HZ, step_hz: STEP_HZ)

  stream.run(&make_handler.call(aggregator))
end

connect_pico_btn.addEventListener("click") do
  scan_status_el[:textContent] = "Pico ポート選択中..."
  peak_tbody_el[:innerHTML]    = "<tr><td colspan=\"3\">接続待ち</td></tr>"

  aggregator = Aggregator.new(channel_count: CHANNEL_COUNT, pixel_count: CHANNEL_COUNT)
  client = SerialClient.new

  client.request_and_open(
    on_ready: lambda do |c|
      scan_status_el[:textContent] = "Pico 接続済み．受信中..."
      peak_tbody_el[:innerHTML]    = "<tr><td colspan=\"3\">受信中...</td></tr>"
      c.run(&make_handler.call(aggregator))
    end,
    on_error: lambda do |msg|
      scan_status_el[:textContent] = "接続エラー: #{msg}"
    end,
  )
end