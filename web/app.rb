require "js"
require "json"

START_HZ          = 76_000_000
STEP_HZ           = 100_000
CHANNEL_COUNT     = 191
PEAK_THRESHOLD    = 10

def html_escape(s)
  s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;").gsub("'", "&#39;")
end

document         = JS.global[:document]
canvas           = document.getElementById("spectrum")
status_el        = document.getElementById("status")
start_mock_btn   = document.getElementById("start-mock")
connect_pico_btn = document.getElementById("connect-pico")
scan_status_el   = document.getElementById("scan-status")
peak_tbody_el    = document.getElementById("peak-tbody")
region_select_el = document.getElementById("region")

renderer = CanvasRenderer.new(
  canvas,
  start_hz:      START_HZ,
  step_hz:       STEP_HZ,
  channel_count: CHANNEL_COUNT,
)

renderer.clear
renderer.draw_axis

directory = nil
begin
  response = JS.global.call(:fetch, "./data/stations.json").await
  unless response[:ok].to_s == "true"
    raise "HTTP #{response[:status].to_i}"
  end
  stations_data = JSON.parse(response.call(:text).await.to_s)
  directory = StationDirectory.new(stations_data)
rescue => e
  status_el[:textContent]     = "局データ読み込みエラー: #{e.message}"
  status_el[:className]       = "status error"
  start_mock_btn[:disabled]   = true
  connect_pico_btn[:disabled] = true
end

if directory
  status_el[:textContent] = "Ruby.wasm 起動成功: Ruby #{RUBY_VERSION}"
  status_el[:className]   = "status ok"

  finalize_scan = lambda do |aggregator, region_key|
    rssi_array = aggregator.pixels
    peaks = PeakDetector.detect(rssi_array, threshold: PEAK_THRESHOLD)
    named = peaks.map do |peak|
      freq_hz = START_HZ + STEP_HZ * peak[:i]
      station = directory.lookup(region_key, freq_hz)
      {
        ch_index: peak[:i],
        freq_hz:  freq_hz,
        rssi:     peak[:rssi],
        name:     station ? station["name"] : "(未登録)",
        kind:     station ? station["kind"] : nil,
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
      "<tr><td>#{mhz} MHz</td><td>#{p[:rssi]}/15</td><td>#{html_escape(p[:name])}</td></tr>"
    end.join
    peak_tbody_el[:innerHTML] = rows.empty? ? "<tr><td colspan=\"3\">検出なし</td></tr>" : rows
    scan_status_el[:textContent] = "完了 (#{named.size} 局検出)"
  end

  make_handler = lambda do |aggregator, region_key, on_finish|
    lambda do |msg|
      case msg["t"]
      when "tick"
        aggregator.clear if msg["i"] == 0
        aggregator.update(msg["i"], msg["f"], msg["rssi"])
        renderer.clear
        renderer.draw_axis
        renderer.draw_bars(aggregator.pixels, msg["i"])
        scan_status_el[:textContent] = "スキャン中: #{msg["i"] + 1}/#{CHANNEL_COUNT} ch"
      when "done"
        finalize_scan.call(aggregator, region_key)
        on_finish&.call
      when "error"
        scan_status_el[:textContent] = "受信エラー: #{msg["msg"]}"
        on_finish&.call
      else
        JS.global[:console].call(:warn, "Unknown stream message type: #{msg["t"]}")
      end
    rescue => e
      scan_status_el[:textContent] = "スキャン中エラー: #{e.message}"
      on_finish&.call
    end
  end

  pico_client = nil

  start_mock_btn.addEventListener("click") do
    next if start_mock_btn[:disabled].to_s == "true"
    start_mock_btn[:disabled]   = true
    connect_pico_btn[:disabled] = true
    pico_client&.close
    pico_client = nil

    region_key = region_select_el[:value].to_s
    station_freqs_khz = directory.stations(region_key).map { |s| s["freq_khz"] }

    scan_status_el[:textContent] = "モックスキャン中..."
    peak_tbody_el[:innerHTML]    = "<tr><td colspan=\"3\">スキャン中...</td></tr>"

    aggregator = Aggregator.new(channel_count: CHANNEL_COUNT, pixel_count: CHANNEL_COUNT)
    source = MockSource.new(
      start_hz:          START_HZ,
      step_hz:           STEP_HZ,
      channel_count:     CHANNEL_COUNT,
      station_freqs_khz: station_freqs_khz,
      seed:              42,
    )
    stream = MockStream.new(source, start_hz: START_HZ, step_hz: STEP_HZ)

    on_finish = lambda do
      start_mock_btn[:disabled]   = false
      connect_pico_btn[:disabled] = false
    end
    stream.run(&make_handler.call(aggregator, region_key, on_finish))
  rescue => e
    scan_status_el[:textContent] = "スキャン準備エラー: #{e.message}"
    start_mock_btn[:disabled]   = false
    connect_pico_btn[:disabled] = false
  end

  connect_pico_btn.addEventListener("click") do
    next if connect_pico_btn[:disabled].to_s == "true"
    connect_pico_btn[:disabled] = true
    start_mock_btn[:disabled]   = true

    pico_client&.close
    pico_client = nil

    region_key = region_select_el[:value].to_s

    scan_status_el[:textContent] = "Pico ポート選択中..."
    peak_tbody_el[:innerHTML]    = "<tr><td colspan=\"3\">接続待ち</td></tr>"

    aggregator = Aggregator.new(channel_count: CHANNEL_COUNT, pixel_count: CHANNEL_COUNT)
    client = SerialClient.new
    pico_client = client

    on_stream_end = lambda do |message|
      next unless pico_client.equal?(client)
      scan_status_el[:textContent] = "Pico 切断: #{message}"
      connect_pico_btn[:disabled]  = false
      start_mock_btn[:disabled]    = false
      client.close
      pico_client = nil
    end

    client.request_and_open(
      on_ready: lambda do |c|
        next unless pico_client.equal?(client)
        scan_status_el[:textContent] = "Pico 接続済み．受信中..."
        peak_tbody_el[:innerHTML]    = "<tr><td colspan=\"3\">受信中...</td></tr>"
        connect_pico_btn[:disabled]  = false
        c.run(on_error: on_stream_end, &make_handler.call(aggregator, region_key, nil))
      end,
      on_error: lambda do |message|
        next unless pico_client.equal?(client)
        scan_status_el[:textContent] = "接続エラー: #{message}"
        connect_pico_btn[:disabled]  = false
        start_mock_btn[:disabled]    = false
        pico_client = nil
      end,
    )
  rescue => e
    scan_status_el[:textContent] = "接続準備エラー: #{e.message}"
    connect_pico_btn[:disabled] = false
    start_mock_btn[:disabled]   = false
  end
end
