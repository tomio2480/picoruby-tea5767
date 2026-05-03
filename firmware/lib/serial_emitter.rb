require "json"

class SerialEmitter
  def initialize(out)
    @out = out
  end

  def tick(i:, f:, rssi:, stereo:)
    emit({ "t" => "tick", "i" => i, "f" => f, "rssi" => rssi, "stereo" => stereo })
  end

  def done(peak:)
    emit({ "t" => "done", "peak" => peak })
  end

  def error(msg:)
    emit({ "t" => "error", "msg" => msg })
  end

  private

  def emit(data)
    @out.puts(JSON.generate(data))
  end
end