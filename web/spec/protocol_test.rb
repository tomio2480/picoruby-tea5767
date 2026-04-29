require "minitest/autorun"
require_relative "../lib/protocol"

class ProtocolTest < Minitest::Test
  def test_tickメッセージをパースできる
    line = '{"t":"tick","i":42,"f":80200000,"rssi":9,"stereo":false}'
    msg = Protocol.parse(line)

    assert_equal "tick", msg["t"]
    assert_equal 42, msg["i"]
    assert_equal 80_200_000, msg["f"]
    assert_equal 9, msg["rssi"]
    assert_equal false, msg["stereo"]
  end

  def test_doneメッセージをパースできる
    line = '{"t":"done","peak":{"i":47,"f":80700000,"rssi":15}}'
    msg = Protocol.parse(line)

    assert_equal "done", msg["t"]
    assert_equal({ "i" => 47, "f" => 80_700_000, "rssi" => 15 }, msg["peak"])
  end

  def test_errorメッセージをパースできる
    line = '{"t":"error","msg":"i2c_timeout"}'
    msg = Protocol.parse(line)

    assert_equal "error", msg["t"]
    assert_equal "i2c_timeout", msg["msg"]
  end

  def test_壊れたJSONはnilを返す
    assert_nil Protocol.parse('{t:"tick"')
  end

  def test_空文字列はnilを返す
    assert_nil Protocol.parse("")
  end

  def test_nilはnilを返す
    assert_nil Protocol.parse(nil)
  end

  def test_未知のtypeはnilを返す
    assert_nil Protocol.parse('{"t":"unknown","x":1}')
  end

  def test_JSONがHashでない場合はnilを返す
    assert_nil Protocol.parse('[1, 2, 3]')
  end

  def test_typeフィールドが欠けている場合はnilを返す
    assert_nil Protocol.parse('{"x":1}')
  end

  def test_行末の改行や前後の空白は無視される
    line = "  {\"t\":\"tick\",\"i\":0,\"f\":76000000,\"rssi\":0,\"stereo\":false}\n"
    msg = Protocol.parse(line)

    assert_equal "tick", msg["t"]
  end

  def test_tickでiフィールドが欠落していたらnilを返す
    assert_nil Protocol.parse('{"t":"tick","f":80200000,"rssi":9,"stereo":false}')
  end

  def test_tickでiが整数でない場合はnilを返す
    assert_nil Protocol.parse('{"t":"tick","i":"42","f":80200000,"rssi":9,"stereo":false}')
  end

  def test_tickでfが整数でない場合はnilを返す
    assert_nil Protocol.parse('{"t":"tick","i":42,"f":80200000.5,"rssi":9,"stereo":false}')
  end

  def test_tickでrssiが欠落していたらnilを返す
    assert_nil Protocol.parse('{"t":"tick","i":42,"f":80200000,"stereo":false}')
  end

  def test_tickでstereoがboolean以外の場合はnilを返す
    assert_nil Protocol.parse('{"t":"tick","i":42,"f":80200000,"rssi":9,"stereo":"yes"}')
  end

  def test_doneでpeakが欠落していたらnilを返す
    assert_nil Protocol.parse('{"t":"done"}')
  end

  def test_doneでpeakがHashでない場合はnilを返す
    assert_nil Protocol.parse('{"t":"done","peak":[1,2,3]}')
  end

  def test_doneでpeak内のフィールドが欠落していたらnilを返す
    assert_nil Protocol.parse('{"t":"done","peak":{"i":47,"f":80700000}}')
  end

  def test_errorでmsgが欠落していたらnilを返す
    assert_nil Protocol.parse('{"t":"error"}')
  end

  def test_errorでmsgが文字列でない場合はnilを返す
    assert_nil Protocol.parse('{"t":"error","msg":42}')
  end
end