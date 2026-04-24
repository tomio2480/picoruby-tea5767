# PicoRuby R2P2 実機で動作させる結線コード．
# CRuby テストの対象外（I2C / sleep_ms などハードウェア API に依存）．
#
# 想定している API:
#   - I2C.new(unit:, frequency:) で I2C バスを開く
#   - i2c.write(address, bytes) / i2c.read(address, n)
#   - sleep_ms(ms) はグローバル関数として使える
#   - $stdout.puts(str) が USB CDC シリアルに流れる
#
# R2P2 のバージョンにより API が変わる場合は I2C 初期化と sleeper を調整する．

require_relative "lib/tea5767"
require_relative "lib/spectrum_scanner"
require_relative "lib/serial_emitter"

START_HZ      = 76_000_000
STEP_HZ       = 100_000
CHANNEL_COUNT = 191
IDLE_MS       = 500

i2c      = I2C.new(unit: :RP2040_I2C0, frequency: 100_000)
receiver = TEA5767.new(i2c)
emitter  = SerialEmitter.new($stdout)
scanner  = SpectrumScanner.new(
  receiver,
  start_hz: START_HZ,
  step_hz:  STEP_HZ,
  count:    CHANNEL_COUNT,
  sleeper:  ->(ms) { sleep_ms(ms) },
)

loop do
  peak_index = 0
  peak_rssi  = -1

  scanner.scan do |i, freq, status|
    emitter.tick(i: i, f: freq, rssi: status[:rssi], stereo: status[:stereo])
    if status[:rssi] > peak_rssi
      peak_rssi  = status[:rssi]
      peak_index = i
    end
  end

  emitter.done(peak: {
    "i"    => peak_index,
    "f"    => START_HZ + STEP_HZ * peak_index,
    "rssi" => peak_rssi,
  })

  sleep_ms(IDLE_MS)
end