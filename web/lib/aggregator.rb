class Aggregator
  attr_reader :dropped_frequencies

  def initialize(channel_count:, pixel_count:)
    unless channel_count.is_a?(Integer) && channel_count.positive?
      raise ArgumentError, "channel_count must be a positive Integer"
    end
    unless pixel_count.is_a?(Integer) && pixel_count.positive?
      raise ArgumentError, "pixel_count must be a positive Integer"
    end

    @channel_count       = channel_count
    @pixel_count         = pixel_count
    @rssi                = Array.new(channel_count, 0)
    @dropped_frequencies = []
  end

  def update(channel_index, frequency_hz, rssi)
    if channel_index < 0 || channel_index >= @channel_count
      @dropped_frequencies << frequency_hz
      return self
    end
    @rssi[channel_index] = rssi
    self
  end

  def clear_dropped_frequencies
    @dropped_frequencies = []
    self
  end

  def pixels
    Array.new(@pixel_count) do |px|
      ch_start = (px * @channel_count) / @pixel_count
      ch_end   = ((px + 1) * @channel_count) / @pixel_count
      ch_end   = ch_start + 1 if ch_end <= ch_start
      @rssi[ch_start...ch_end].max
    end
  end
end
