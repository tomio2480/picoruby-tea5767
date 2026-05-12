class SpectrumScanner
  def initialize(receiver, start_hz, step_hz, count, wait_ms = 0)
    @receiver = receiver
    @start_hz = start_hz
    @step_hz  = step_hz
    @count    = count
    @wait_ms  = wait_ms
  end

  def scan
    @count.times do |i|
      freq = @start_hz + (@step_hz * i)
      @receiver.tune(freq)
      sleep_ms(@wait_ms)
      status = @receiver.status
      yield(i, freq, status) if block_given?
    end
  end
end
