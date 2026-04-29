require "minitest/autorun"
require_relative "../lib/aggregator"

class AggregatorTest < Minitest::Test
  def test_ピクセル数がチャンネル数と等しいときは恒等集約になる
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 4)
    [3, 7, 11, 15].each_with_index do |rssi, i|
      aggregator.update(i, 76_000_000 + i * 100_000, rssi)
    end

    assert_equal [3, 7, 11, 15], aggregator.pixels
  end

  def test_チャンネル数がピクセル数を上回るときは複数chの最大値で集約される
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    [3, 7, 11, 15].each_with_index do |rssi, i|
      aggregator.update(i, 76_000_000 + i * 100_000, rssi)
    end

    assert_equal [7, 15], aggregator.pixels
  end

  def test_初期状態のpixelsは全て0である
    aggregator = Aggregator.new(channel_count: 191, pixel_count: 128)

    assert_equal [0] * 128, aggregator.pixels
  end

  def test_未更新のチャンネルは初期値0として扱われる
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    aggregator.update(2, 76_200_000, 9)

    assert_equal [0, 9], aggregator.pixels
  end

  def test_191chを128pxに集約したとき両端のchが正しい位置に反映される
    aggregator = Aggregator.new(channel_count: 191, pixel_count: 128)
    aggregator.update(0,   76_000_000, 15)
    aggregator.update(190, 95_000_000, 12)

    pixels = aggregator.pixels
    assert_equal 15, pixels.first
    assert_equal 12, pixels.last
  end

  def test_範囲外indexのupdateはpixelsに影響しない
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    aggregator.update(0, 76_000_000, 5)
    aggregator.update(-1, 75_900_000, 99)
    aggregator.update(99, 99_000_000, 99)
    aggregator.update(2, 76_200_000, 7)

    assert_equal [5, 7], aggregator.pixels
  end

  def test_初期状態のdropped_frequenciesは空である
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)

    assert_equal [], aggregator.dropped_frequencies
  end

  def test_範囲外indexのupdateはdropped_frequenciesに記録される
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    aggregator.update(-1, 75_900_000, 9)
    aggregator.update(4,  76_400_000, 7)

    assert_equal [75_900_000, 76_400_000], aggregator.dropped_frequencies
  end

  def test_同一周波数の複数drop_は全件残る
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    aggregator.update(99, 80_000_000, 1)
    aggregator.update(99, 80_000_000, 2)

    assert_equal [80_000_000, 80_000_000], aggregator.dropped_frequencies
  end

  def test_clear_dropped_frequenciesで履歴をリセットできる
    aggregator = Aggregator.new(channel_count: 4, pixel_count: 2)
    aggregator.update(99, 80_000_000, 1)
    aggregator.clear_dropped_frequencies

    assert_equal [], aggregator.dropped_frequencies
  end
end