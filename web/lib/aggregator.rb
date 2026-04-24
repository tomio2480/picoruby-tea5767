class Aggregator
  def initialize(channel_count:, pixel_count:)
    @channel_count = channel_count
    @pixel_count   = pixel_count
    @rssi          = Array.new(channel_count, 0)
  end

  def update(channel_index, rssi)
    @rssi[channel_index] = rssi
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