class SpectrumScanner
  def initialize(receiver, start_hz:, step_hz:, count:, sleeper: ->(_ms) {})
    @receiver = receiver
    @start_hz = start_hz
    @step_hz  = step_hz
    @count    = count
    @sleeper  = sleeper
  end

  def scan
    @count.times do |i|
      freq = @start_hz + @step_hz * i
      @receiver.tune(freq)
      @sleeper.call(TEA5767::PLL_LOCK_WAIT_MS)
      status = @receiver.status
      yield(i, freq, status) if block_given?
    end
  end
end