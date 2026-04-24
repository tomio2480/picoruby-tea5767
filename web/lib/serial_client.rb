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
      options = JS.eval("({ baudRate: #{@baud} })")
      port.call(:open, options).call(:then) do |_|
        @reader = port[:readable].call(:getReader)
        on_ready.call(self) if on_ready
      end
    end.call(:catch) do |err|
      on_error.call(err.to_s) if on_error
    end
  end

  def run(&block)
    buffer = ""
    decoder = JS.eval("new TextDecoder()")

    read_next = nil
    read_next = lambda do
      @reader.call(:read).call(:then) do |result|
        next if result[:done] == true

        chunk_str = decoder.call(:decode, result[:value]).to_s
        buffer += chunk_str
        while (idx = buffer.index("\n"))
          line = buffer[0...idx]
          buffer = buffer[(idx + 1)..]
          msg = Protocol.parse(line)
          block.call(msg) if msg
        end
        read_next.call
      end
    end
    read_next.call
  end

  def close
    @reader.call(:releaseLock) if @reader
    @port.call(:close) if @port
  end
end