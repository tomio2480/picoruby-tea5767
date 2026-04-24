class MockSource
  STATION_TOLERANCE_KHZ = 50
  STATION_RSSI_RANGE = (11..15).freeze
  NOISE_RSSI_RANGE   = (0..4).freeze

  def initialize(start_hz:, step_hz:, channel_count:, station_freqs_khz:, seed: 42)
    @start_hz          = start_hz
    @step_hz           = step_hz
    @channel_count     = channel_count
    @station_freqs_khz = station_freqs_khz
    @seed              = seed
  end

  def generate_rssi
    rng = Random.new(@seed)
    Array.new(@channel_count) do |i|
      freq_khz = (@start_hz + @step_hz * i) / 1_000
      range = near_station?(freq_khz) ? STATION_RSSI_RANGE : NOISE_RSSI_RANGE
      rng.rand(range)
    end
  end

  private

  def near_station?(freq_khz)
    @station_freqs_khz.any? { |s| (s - freq_khz).abs <= STATION_TOLERANCE_KHZ }
  end
end