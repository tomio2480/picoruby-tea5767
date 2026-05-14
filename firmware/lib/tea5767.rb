class TEA5767
  ADDRESS          = 0x60
  IF_FREQ_HZ       = 225_000
  XTAL_FREQ_HZ     = 32_768
  PLL_LOCK_WAIT_MS = 50

  # 目標周波数 freq_hz との実周波数誤差を最小にする PLL 分周比を返す．
  # 線形関係下ではこの基準は .round と等価．
  # 議論経緯: docs/notes/2026-04-23-review-log.md §1c
  def self.pll_for(freq_hz)
    (4.0 * (freq_hz + IF_FREQ_HZ) / XTAL_FREQ_HZ).round
  end

  def initialize(i2c)
    @i2c      = i2c
    @last_pll = self.class.pll_for(76_000_000)  # 初期値: バンド最低周波数
  end

  def tune(freq_hz)
    @last_pll = self.class.pll_for(freq_hz)
    @i2c.write(
      ADDRESS,
      (@last_pll >> 8) & 0x3F,   # MUTE=0, SM=0, PLL[13:8]
      @last_pll & 0xFF,            # PLL[7:0]
      0b1011_0000,                 # SUD=1, SSL=01, HLSI=1, MS=0
      0b0001_0000,                 # XTAL=1
      0b0000_0000,                 # PLLREF=0, DTC=0 (50 μs)
    )
  end

  # MUTE ビットを立てつつ最後の PLL 値を保持する．
  # PLL=0 を送ると TEA5767 が異常状態になるため @last_pll を使う．
  def mute
    @i2c.write(
      ADDRESS,
      ((@last_pll >> 8) & 0x3F) | 0x80,   # MUTE=1, PLL[13:8]
      @last_pll & 0xFF,                     # PLL[7:0]
      0b1011_0000,                          # SUD=1, SSL=01, HLSI=1, MS=0
      0b0001_0000,                          # XTAL=1
      0b0000_0000,                          # PLLREF=0, DTC=0 (50 μs)
    )
  end

  def status
    res = @i2c.read(ADDRESS, 5)
    return { ready: false, stereo: false, rssi: 0 } if res.to_s.length < 5
    b = res.bytes
    {
      ready:  ((b[0] >> 7) & 1) == 1,
      stereo: ((b[2] >> 7) & 1) == 1,
      rssi:   (b[3] >> 4) & 0x0F,
    }
  end
end
