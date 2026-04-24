require "json"

module Protocol
  KNOWN_TYPES = %w[tick done error].freeze

  module_function

  def parse(line)
    return nil if line.nil?
    return nil if line.strip.empty?

    data = JSON.parse(line)
    return nil unless data.is_a?(Hash)
    return nil unless KNOWN_TYPES.include?(data["t"])

    data
  rescue JSON::ParserError
    nil
  end
end