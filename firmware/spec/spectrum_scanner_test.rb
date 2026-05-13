require "minitest/autorun"
require_relative "../lib/spectrum_scanner"

# PicoRuby が提供する sleep_ms を CRuby のテスト用にスタブする．
# 呼び出し回数と引数を $sleep_ms_calls で確認できる．
$sleep_ms_calls = []
def sleep_ms(ms)
  $sleep_ms_calls << ms
end

class FakeReceiver
  attr_reader :tune_calls, :status_calls

  def initialize(rssi_map: {})
    @tune_calls   = []
    @status_calls = 0
    @rssi_map     = rssi_map
    @current_freq = nil
  end

  def tune(freq_hz)
    @tune_calls << freq_hz
    @current_freq = freq_hz
  end

  def status
    @status_calls += 1
    { ready: true, stereo: false, rssi: @rssi_map[@current_freq] || 0 }
  end
end

class SpectrumScannerTest < Minitest::Test
  def setup
    $sleep_ms_calls = []
  end

  def build_scanner(count: 3, wait_ms: 0)
    @receiver = FakeReceiver.new
    SpectrumScanner.new(@receiver, 76_000_000, 100_000, count, wait_ms)
  end

  def test_scanはcount回tuneを呼ぶ
    scanner = build_scanner(count: 5)
    scanner.scan

    assert_equal 5, @receiver.tune_calls.size
  end

  def test_scanはstart_hzから順にstep_hz刻みでtuneする
    scanner = build_scanner(count: 3)
    scanner.scan

    assert_equal [76_000_000, 76_100_000, 76_200_000], @receiver.tune_calls
  end

  def test_scanは各chでstatusを呼ぶ
    scanner = build_scanner(count: 4)
    scanner.scan

    assert_equal 4, @receiver.status_calls
  end

  def test_scanはyieldにインデックスと周波数とstatusを渡す
    scanner = build_scanner(count: 2)
    received = []
    scanner.scan { |i, freq, status| received << [i, freq, status[:rssi]] }

    assert_equal [[0, 76_000_000, 0], [1, 76_100_000, 0]], received
  end

  def test_sleep_msは指定したwait_msで各chで呼ばれる
    scanner = build_scanner(count: 3, wait_ms: 7)
    scanner.scan

    assert_equal [7, 7, 7], $sleep_ms_calls
  end

  def test_wait_ms未指定時はsleep_msが0で呼ばれる
    @receiver = FakeReceiver.new
    scanner = SpectrumScanner.new(@receiver, 76_000_000, 100_000, 2)
    scanner.scan

    assert_equal [0, 0], $sleep_ms_calls
  end

  def test_scanはブロックなしでも例外にならず完了する
    scanner = build_scanner(count: 2)
    scanner.scan

    assert_equal 2, @receiver.tune_calls.size
  end
end
