require "minitest/autorun"
require_relative "../lib/tea5767"

class FakeI2C
  attr_reader :last_write

  def initialize(read_data: [0, 0, 0, 0, 0])
    @read_data = read_data
    @last_write = nil
  end

  def write(address, *bytes)
    @last_write = { address: address, bytes: bytes.dup }
  end

  def read(_address, n)
    @read_data.first(n).pack("C*")
  end
end

class TEA5767Test < Minitest::Test
  def test_pll_for_82_5MHzは10098
    assert_equal 10098, TEA5767.pll_for(82_500_000)
  end

  def test_pll_for_76_0MHzは9304
    assert_equal 9304, TEA5767.pll_for(76_000_000)
  end

  def test_pll_for_95_0MHzは11624
    assert_equal 11624, TEA5767.pll_for(95_000_000)
  end

  def test_tuneはI2Cに0x60アドレス宛で5バイトを書く
    fake_i2c = FakeI2C.new
    TEA5767.new(fake_i2c).tune(82_500_000)

    assert_equal 0x60, fake_i2c.last_write[:address]
    assert_equal 5,    fake_i2c.last_write[:bytes].size
  end

  def test_tuneはPLL上位6ビットを1バイト目下位に格納する
    fake_i2c = FakeI2C.new
    TEA5767.new(fake_i2c).tune(82_500_000)

    pll = TEA5767.pll_for(82_500_000)
    assert_equal (pll >> 8) & 0x3F, fake_i2c.last_write[:bytes][0]
  end

  def test_tuneはPLL下位8ビットを2バイト目に格納する
    fake_i2c = FakeI2C.new
    TEA5767.new(fake_i2c).tune(82_500_000)

    pll = TEA5767.pll_for(82_500_000)
    assert_equal pll & 0xFF, fake_i2c.last_write[:bytes][1]
  end

  def test_tuneの3バイト目はHLSI1とMS0をセットする
    fake_i2c = FakeI2C.new
    TEA5767.new(fake_i2c).tune(82_500_000)

    byte3 = fake_i2c.last_write[:bytes][2]
    assert_equal 1, (byte3 >> 4) & 1, "HLSI (bit4) should be 1"
    assert_equal 0, (byte3 >> 3) & 1, "MS (bit3) should be 0 (stereo)"
  end

  def test_tuneの4バイト目はXTAL1をセットする
    fake_i2c = FakeI2C.new
    TEA5767.new(fake_i2c).tune(82_500_000)

    byte4 = fake_i2c.last_write[:bytes][3]
    assert_equal 1, (byte4 >> 4) & 1, "XTAL (bit4) should be 1"
  end

  def test_statusは読み出しバイト1のbit7からreadyを得る
    fake_i2c = FakeI2C.new(read_data: [0x80, 0, 0, 0, 0])
    assert_equal true, TEA5767.new(fake_i2c).status[:ready]

    fake_i2c = FakeI2C.new(read_data: [0x00, 0, 0, 0, 0])
    assert_equal false, TEA5767.new(fake_i2c).status[:ready]
  end

  def test_statusは読み出しバイト3のbit7からstereoを得る
    fake_i2c = FakeI2C.new(read_data: [0, 0, 0x80, 0, 0])
    assert_equal true, TEA5767.new(fake_i2c).status[:stereo]

    fake_i2c = FakeI2C.new(read_data: [0, 0, 0x00, 0, 0])
    assert_equal false, TEA5767.new(fake_i2c).status[:stereo]
  end

  def test_statusは読み出しバイト4の上位4ビットからRSSIを得る
    fake_i2c = FakeI2C.new(read_data: [0, 0, 0, 0xA0, 0])
    assert_equal 10, TEA5767.new(fake_i2c).status[:rssi]

    fake_i2c = FakeI2C.new(read_data: [0, 0, 0, 0xF0, 0])
    assert_equal 15, TEA5767.new(fake_i2c).status[:rssi]

    fake_i2c = FakeI2C.new(read_data: [0, 0, 0, 0x00, 0])
    assert_equal 0, TEA5767.new(fake_i2c).status[:rssi]
  end
end