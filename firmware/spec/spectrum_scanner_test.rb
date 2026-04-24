require "minitest/autorun"
require_relative "../lib/tea5767"
require_relative "../lib/spectrum_scanner"

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
  def build_scanner(count: 3, sleeper: ->(_ms) {})
    @receiver = FakeReceiver.new
    SpectrumScanner.new(
      @receiver,
      start_hz: 76_000_000,
      step_hz:  100_000,
      count:    count,
      sleeper:  sleeper,
    )
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

  def test_sleeperはPLL_LOCK_WAIT_MSで各chで呼ばれる
    sleep_calls = []
    sleeper = ->(ms) { sleep_calls << ms }
    scanner = build_scanner(count: 3, sleeper: sleeper)
    scanner.scan

    assert_equal [TEA5767::PLL_LOCK_WAIT_MS] * 3, sleep_calls
  end

  def test_scanはブロックなしでも例外にならず完了する
    scanner = build_scanner(count: 2)
    scanner.scan

    assert_equal 2, @receiver.tune_calls.size
  end
end