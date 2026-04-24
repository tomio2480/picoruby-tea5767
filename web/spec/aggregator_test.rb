require "minitest/autorun"
require_relative "../lib/aggregator"

class AggregatorTest < Minitest::Test
  def test_ピクセル数がチャンネル数と等しいときは恒等集約になる
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 4)
    [3, 7, 11, 15].each_with_index do |rssi, i|
      aggregator.update(i, rssi)
    end

    assert_equal [3, 7, 11, 15], aggregator.pixels
  end

  def test_チャンネル数がピクセル数を上回るときは複数chの最大値で集約される
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    [3, 7, 11, 15].each_with_index do |rssi, i|
      aggregator.update(i, rssi)
    end

    assert_equal [7, 15], aggregator.pixels
  end

  def test_初期状態のpixelsは全て0である
    aggregator = Aggregator.new(channel_count: 191, pixel_count: 128)

    assert_equal [0] * 128, aggregator.pixels
  end

  def test_未更新のチャンネルは初期値0として扱われる
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    aggregator.update(2, 9)

    assert_equal [0, 9], aggregator.pixels
  end

  def test_191chを128pxに集約したとき両端のchが正しい位置に反映される
    aggregator = Aggregator.new(channel_count: 191, pixel_count: 128)
    aggregator.update(0, 15)
    aggregator.update(190, 12)

    pixels = aggregator.pixels
    assert_equal 15, pixels.first
    assert_equal 12, pixels.last
  end
end