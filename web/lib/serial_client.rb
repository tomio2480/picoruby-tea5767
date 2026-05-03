require "js"

class SerialClient
  DEFAULT_BAUD = 115_200

  def initialize(baud: DEFAULT_BAUD)
    @baud   = baud
    @reader = nil
    @port   = nil
  end

  def request_and_open(on_ready: nil, on_error: nil)
    serial = JS.global[:navigator][:serial]

    serial.call(:requestPort).call(:then) do |port|
      @port = port
      options = JS.global[:Object].new
      options[:baudRate] = @baud
      port.call(:open, options).call(:then) do |_|
        @reader = port[:readable].call(:getReader)
        on_ready.call(self) if on_ready
      end
    end.call(:catch) do |err|
      msg = err[:message].to_s
      message = (msg.empty? || msg == "undefined") ? err.to_s : msg
      on_error.call(message) if on_error
    end
  end

  def run(on_error: nil, &block)
    buffer = ""
    decoder = JS.global[:TextDecoder].new

    read_next = nil
    read_next = lambda do
      return if @reader.nil?
      @reader.call(:read).call(:then) do |result|
        next if @reader.nil?
        if result[:done].to_s == "true"
          on_error.call("ストリーム終了") if on_error
          next
        end

        chunk_str = decoder.call(:decode, result[:value]).to_s
        buffer += chunk_str
        while (idx = buffer.index("\n"))
          line = buffer[0...idx]
          buffer = buffer[(idx + 1)..]
          msg = Protocol.parse(line)
          if msg
            block.call(msg)
          elsif !line.strip.empty?
            JS.global[:console].call(:warn, "Failed to parse line: #{line}")
          end
        end
        read_next.call
      end.call(:catch) do |err|
        msg = err[:message].to_s
        message = (msg.empty? || msg == "undefined") ? err.to_s : msg
        on_error.call(message) if on_error
      end
    end
    read_next.call
  end

  def close
    return if @port.nil?
    reader_to_close = @reader
    port_to_close   = @port
    @reader = nil
    @port   = nil

    if reader_to_close
      reader_to_close.call(:cancel).call(:then) do
        begin
          reader_to_close.call(:releaseLock)
        rescue
          # 既にリリース済みなど
        end
        begin
          port_to_close.call(:close)
        rescue
          # 既にクローズ済みなど
        end
      end.call(:catch) do |_|
        begin
          port_to_close.call(:close)
        rescue
          # 既にクローズ済みなど
        end
      end
    else
      begin
        port_to_close.call(:close)
      rescue
        # 既にクローズ済みなど
      end
    end
  end
end
