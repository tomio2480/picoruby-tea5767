require "minitest/autorun"
require_relative "../lib/canvas_renderer"

class CanvasRendererTest < Minitest::Test
  def make_renderer(width: 800, height: 300, channel_count: 191)
    ctx = Object.new.tap do |obj|
      obj.define_singleton_method(:[]) { |_k| nil }
      obj.define_singleton_method(:[]=) { |_k, _v| nil }
      obj.define_singleton_method(:call) { |*_args| nil }
    end
    canvas = Object.new.tap do |obj|
      obj.define_singleton_method(:[]) { |k| { "width" => width, "height" => height }[k.to_s] }
      obj.define_singleton_method(:call) { |*_args| ctx }
    end
    CanvasRenderer.new(canvas, start_hz: 76_000_000, step_hz: 100_000, channel_count: channel_count)
  end

  def test_x_to_ch_index_最左端は0
    assert_equal 0, make_renderer.x_to_ch_index(0)
  end

  def test_x_to_ch_index_中間値が正しく計算される
    # ch_index 50 の左端 x = 50 * (800.0 / 191) ≈ 209.42
    # x = 210 はチャンネル 50 内に収まる
    assert_equal 50, make_renderer.x_to_ch_index(210)
  end

  def test_x_to_ch_index_最右バーの範囲内
    # ch_index 190 の左端 x = 190 * (800.0 / 191) ≈ 795.81
    assert_equal 190, make_renderer.x_to_ch_index(796)
  end

  def test_x_to_ch_index_負の座標は0にクランプ
    assert_equal 0, make_renderer.x_to_ch_index(-10)
  end

  def test_x_to_ch_index_幅を超えた座標は最大チャンネルにクランプ
    assert_equal 190, make_renderer.x_to_ch_index(9999)
  end
end
