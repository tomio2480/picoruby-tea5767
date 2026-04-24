require "minitest/autorun"
require_relative "../lib/peak_detector"

class PeakDetectorTest < Minitest::Test
  def test_空配列の場合はピークなし
    assert_equal [], PeakDetector.detect([], threshold: 8)
  end

  def test_全てのRSSIが閾値未満の場合はピークなし
    assert_equal [], PeakDetector.detect([0, 3, 5, 2, 0], threshold: 8)
  end

  def test_単一のchだけが閾値以上ならそのchをピークとして返す
    assert_equal [{ i: 2, rssi: 10 }], PeakDetector.detect([0, 3, 10, 3, 0], threshold: 8)
  end

  def test_連続する閾値以上のchは最大値chを1つのピークとして返す
    assert_equal [{ i: 3, rssi: 15 }], PeakDetector.detect([0, 9, 12, 15, 10, 0], threshold: 8)
  end

  def test_分離した2つのクラスタはそれぞれピークになる
    rssi = [0, 10, 12, 3, 0, 14, 9, 0]
    assert_equal [{ i: 2, rssi: 12 }, { i: 5, rssi: 14 }], PeakDetector.detect(rssi, threshold: 8)
  end

  def test_閾値ちょうどのRSSIは含める
    assert_equal [{ i: 0, rssi: 8 }], PeakDetector.detect([8, 0], threshold: 8)
  end

  def test_配列先頭から始まるクラスタも検出できる
    assert_equal [{ i: 0, rssi: 12 }], PeakDetector.detect([12, 10, 3], threshold: 8)
  end

  def test_配列末尾まで続くクラスタも検出できる
    assert_equal [{ i: 3, rssi: 15 }], PeakDetector.detect([0, 3, 10, 15], threshold: 8)
  end

  def test_全てのRSSIが閾値以上なら全体で最大値が1つのピーク
    assert_equal [{ i: 2, rssi: 15 }], PeakDetector.detect([9, 10, 15, 12, 11], threshold: 8)
  end
end