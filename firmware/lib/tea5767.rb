class TEA5767
  ADDRESS          = 0x60
  IF_FREQ_HZ       = 225_000
  XTAL_FREQ_HZ     = 32_768
  PLL_LOCK_WAIT_MS = 50

  def self.pll_for(freq_hz)
    4 * (freq_hz + IF_FREQ_HZ) / XTAL_FREQ_HZ
  end

  def initialize(i2c)
    @i2c = i2c
  end

  def tune(freq_hz)
    pll = self.class.pll_for(freq_hz)
    bytes = [
      (pll >> 8) & 0x3F,   # MUTE=0, SM=0, PLL[13:8]
      pll & 0xFF,           # PLL[7:0]
      0b1011_0000,          # SUD=1, SSL=01, HLSI=1, MS=0
      0b0001_0000,          # XTAL=1
      0b0000_0000,          # PLLREF=0, DTC=0 (50 μs)
    ]
    @i2c.write(ADDRESS, bytes)
  end

  def status
    b = @i2c.read(ADDRESS, 5)
    {
      ready:  ((b[0] >> 7) & 1) == 1,
      stereo: ((b[2] >> 7) & 1) == 1,
      rssi:   (b[3] >> 4) & 0x0F,
    }
  end
end