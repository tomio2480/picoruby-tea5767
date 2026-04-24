class StationDirectory
  MATCH_TOLERANCE_KHZ = 50

  def initialize(data)
    @data = data
  end

  def regions
    @data.fetch("regions").keys
  end

  def stations(region_key)
    @data.dig("regions", region_key, "stations") || []
  end

  def lookup(region_key, freq_hz)
    freq_khz = freq_hz / 1_000
    stations(region_key).find do |s|
      (s["freq_khz"] - freq_khz).abs <= MATCH_TOLERANCE_KHZ
    end
  end
end