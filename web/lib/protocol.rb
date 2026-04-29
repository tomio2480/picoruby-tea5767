require "json"

module Protocol
  KNOWN_TYPES = %w[tick done error].freeze

  module_function

  def parse(line)
    return nil unless line.is_a?(String)
    return nil if line.strip.empty?

    data = JSON.parse(line)
    return nil unless data.is_a?(Hash)
    return nil unless KNOWN_TYPES.include?(data["t"])
    return nil unless valid_payload?(data)

    data
  rescue JSON::ParserError
    nil
  end

  def valid_payload?(data)
    case data["t"]
    when "tick"  then valid_tick?(data)
    when "done"  then valid_done?(data)
    when "error" then valid_error?(data)
    else false
    end
  end

  def valid_tick?(data)
    data["i"].is_a?(Integer) &&
      data["f"].is_a?(Integer) &&
      data["rssi"].is_a?(Integer) &&
      (data["stereo"] == true || data["stereo"] == false)
  end

  def valid_done?(data)
    peak = data["peak"]
    return false unless peak.is_a?(Hash)
    peak["i"].is_a?(Integer) &&
      peak["f"].is_a?(Integer) &&
      peak["rssi"].is_a?(Integer)
  end

  def valid_error?(data)
    data["msg"].is_a?(String)
  end
end
