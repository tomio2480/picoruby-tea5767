require "minitest/autorun"
require "stringio"
require "json"
require_relative "../lib/serial_emitter"

class SerialEmitterTest < Minitest::Test
  def setup
    @io      = StringIO.new
    @emitter = SerialEmitter.new(@io)
  end

  def test_tickはJSON_Lines形式のtickメッセージを1行出力する
    @emitter.tick(i: 42, f: 80_200_000, rssi: 9, stereo: false)

    lines = @io.string.lines
    assert_equal 1, lines.size
    parsed = JSON.parse(lines.first)
    assert_equal "tick", parsed["t"]
    assert_equal 42, parsed["i"]
    assert_equal 80_200_000, parsed["f"]
    assert_equal 9, parsed["rssi"]
    assert_equal false, parsed["stereo"]
  end

  def test_doneはpeakフィールドを持つdoneメッセージを出力する
    @emitter.done(peak: { "i" => 47, "f" => 80_700_000, "rssi" => 15 })

    parsed = JSON.parse(@io.string.lines.first)
    assert_equal "done", parsed["t"]
    assert_equal({ "i" => 47, "f" => 80_700_000, "rssi" => 15 }, parsed["peak"])
  end

  def test_errorはmsgフィールドを持つerrorメッセージを出力する
    @emitter.error(msg: "i2c_timeout")

    parsed = JSON.parse(@io.string.lines.first)
    assert_equal "error", parsed["t"]
    assert_equal "i2c_timeout", parsed["msg"]
  end

  def test_複数回呼ぶと改行区切りの複数行になる
    @emitter.tick(i: 0, f: 76_000_000, rssi: 5, stereo: false)
    @emitter.tick(i: 1, f: 76_100_000, rssi: 6, stereo: false)
    @emitter.done(peak: { "i" => 1, "f" => 76_100_000, "rssi" => 6 })

    lines = @io.string.lines
    assert_equal 3, lines.size
    assert_equal "tick", JSON.parse(lines[0])["t"]
    assert_equal "tick", JSON.parse(lines[1])["t"]
    assert_equal "done", JSON.parse(lines[2])["t"]
  end

  def test_stereoがtrueの場合も正しく出力される
    @emitter.tick(i: 10, f: 80_700_000, rssi: 15, stereo: true)

    parsed = JSON.parse(@io.string.lines.first)
    assert_equal true, parsed["stereo"]
  end
end