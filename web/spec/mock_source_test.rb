require "minitest/autorun"
require_relative "../lib/mock_source"

class MockSourceTest < Minitest::Test
  HAKODATE_STATIONS_KHZ = [79_400, 80_700, 83_600, 87_000, 88_800].freeze

  def build_source(seed: 42)
    MockSource.new(
      start_hz: 76_000_000,
      step_hz: 100_000,
      channel_count: 191,
      station_freqs_khz: HAKODATE_STATIONS_KHZ,
      seed: seed
    )
  end

  def test_チャンネル数通りの配列を返す
    assert_equal 191, build_source.generate_rssi.size
  end

  def test_同一シードなら毎回同じ結果を返す
    a = build_source(seed: 42).generate_rssi
    b = build_source(seed: 42).generate_rssi
    assert_equal a, b
  end

  def test_異なるシードなら結果も変わる
    a = build_source(seed: 42).generate_rssi
    b = build_source(seed: 123).generate_rssi
    refute_equal a, b
  end

  def test_函館主要局の中心周波数のchは高いRSSIが入る
    rssi = build_source.generate_rssi
    HAKODATE_STATIONS_KHZ.each do |station_khz|
      ch_index = (station_khz - 76_000) / 100
      assert rssi[ch_index] >= 11,
             "ch #{ch_index} (#{station_khz} kHz) の RSSI #{rssi[ch_index]} が 11 未満"
    end
  end

  def test_主要局から離れたchはノイズ範囲のRSSIが入る
    rssi = build_source.generate_rssi
    ch_index = (86_000 - 76_000) / 100
    assert rssi[ch_index] <= 4,
           "ch #{ch_index} (86.0 MHz) の RSSI #{rssi[ch_index]} がノイズ範囲 (<=4) を超えている"
  end

  def test_RSSIは0から15の範囲に収まる
    rssi = build_source.generate_rssi
    assert rssi.min >= 0
    assert rssi.max <= 15
  end
end