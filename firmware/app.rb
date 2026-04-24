# PicoRuby R2P2 実機で動作させる結線コード．
# R2P2 は起動時に /home/app.rb を自動実行するため、本ファイルを /home/app.rb に配置する．
# lib/*.rb は /home/lib/*.rb に配置し、絶対パスで require する（PicoRuby には require_relative がない）．
# CRuby テストの対象外（I2C / sleep_ms などハードウェア API に依存）．
#
# 確定済みの PicoRuby / R2P2 API:
#   - I2C.new(unit: :RP2040_I2C0, sda_pin:, scl_pin:, frequency:) ... picoruby-i2c
#   - i2c.write(addr, b1, b2, ..., bN) ... 可変長引数
#   - i2c.read(addr, n) ... バイト列 String を返す．呼び出し側で .bytes して Array[Integer] 化
#   - sleep_ms(ms) ... Kernel 拡張．グローバル関数として使用可
#   - puts(str) / $stdout.puts(str) ... CDC 0 (USB シリアル) に流れる

require "i2c"
require "/home/lib/tea5767"
require "/home/lib/spectrum_scanner"
require "/home/lib/serial_emitter"

START_HZ      = 76_000_000
STEP_HZ       = 100_000
CHANNEL_COUNT = 191
IDLE_MS       = 500

i2c      = I2C.new(unit: :RP2040_I2C0, sda_pin: 4, scl_pin: 5, frequency: 100_000)
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