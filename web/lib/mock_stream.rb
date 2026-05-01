require "js"

class MockStream
  def initialize(source, start_hz:, step_hz:, delay_ms: 30)
    @source   = source
    @start_hz = start_hz
    @step_hz  = step_hz
    @delay_ms = delay_ms
  end

  def run(&block)
    rssi = @source.generate_rssi
    peak_index = 0
    peak_rssi  = -1
    step = nil

    step = lambda do |i|
      if i >= rssi.size
        block.call({
          "t" => "done",
          "peak" => {
            "i"    => peak_index,
            "f"    => @start_hz + @step_hz * peak_index,
            "rssi" => peak_rssi,
          },
        })
        next
      end

      r = rssi[i]
      block.call({
        "t"      => "tick",
        "i"      => i,
        "f"      => @start_hz + @step_hz * i,
        "rssi"   => r,
        "stereo" => false,
      })
      if r > peak_rssi
        peak_rssi  = r
        peak_index = i
      end

      JS.global.call(:setTimeout, ->() { step.call(i + 1) }, @delay_ms)
    end

    step.call(0)
  end
end
