class SpectrumScanner
  def initialize(receiver, start_hz:, step_hz:, count:, sleeper: ->(_ms) {}, wait_ms: 0)
    @receiver = receiver
    @start_hz = start_hz
    @step_hz  = step_hz
    @count    = count
    @sleeper  = sleeper
    @wait_ms  = wait_ms
  end

  def scan
    @count.times do |i|
      freq = @start_hz + @step_hz * i
      @receiver.tune(freq)
      @sleeper.call(@wait_ms)
      status = @receiver.status
      yield(i, freq, status) if block_given?
    end
  end
end