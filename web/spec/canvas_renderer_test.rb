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

  # fillRect 呼び出し時点の fillStyle を記録するスパイ付きレンダラーを返す
  def make_renderer_with_color_spy(channel_count: 5)
    colors = []
    current_fill = nil
    ctx = Object.new.tap do |obj|
      obj.define_singleton_method(:[]) { |_k| nil }
      obj.define_singleton_method(:[]=) do |k, v|
        current_fill = v if k.to_s == "fillStyle"
      end
      obj.define_singleton_method(:call) do |method, *_args|
        colors << current_fill if method.to_s == "fillRect"
        nil
      end
    end
    canvas = Object.new.tap do |obj|
      obj.define_singleton_method(:[]) { |k| { "width" => 800, "height" => 300 }[k.to_s] }
      obj.define_singleton_method(:call) { |*_args| ctx }
    end
    renderer = CanvasRenderer.new(canvas, start_hz: 76_000_000, step_hz: 100_000, channel_count: channel_count)
    [renderer, colors]
  end

  # ---- x_to_ch_index ----

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

  # ---- draw_bars の色選択ロジック ----

  def test_draw_bars_通常バーはBAR_COLOR
    renderer, colors = make_renderer_with_color_spy
    renderer.draw_bars([5] * 5)
    assert_equal [CanvasRenderer::BAR_COLOR] * 5, colors
  end

  def test_draw_bars_cursor_indexのバーはCURSOR_COLOR
    renderer, colors = make_renderer_with_color_spy
    renderer.draw_bars([5] * 5, 2)
    expected = [CanvasRenderer::BAR_COLOR, CanvasRenderer::BAR_COLOR,
                CanvasRenderer::CURSOR_COLOR,
                CanvasRenderer::BAR_COLOR, CanvasRenderer::BAR_COLOR]
    assert_equal expected, colors
  end

  def test_draw_bars_hover_indexのバーはHOVER_COLOR
    renderer, colors = make_renderer_with_color_spy
    renderer.draw_bars([5] * 5, nil, 1)
    expected = [CanvasRenderer::BAR_COLOR, CanvasRenderer::HOVER_COLOR,
                CanvasRenderer::BAR_COLOR, CanvasRenderer::BAR_COLOR, CanvasRenderer::BAR_COLOR]
    assert_equal expected, colors
  end

  def test_draw_bars_cursor_indexとhover_indexが重なった場合はCURSOR_COLORが優先
    renderer, colors = make_renderer_with_color_spy
    renderer.draw_bars([5] * 5, 3, 3)
    expected = [CanvasRenderer::BAR_COLOR, CanvasRenderer::BAR_COLOR,
                CanvasRenderer::BAR_COLOR, CanvasRenderer::CURSOR_COLOR, CanvasRenderer::BAR_COLOR]
    assert_equal expected, colors
  end

  def test_draw_bars_cursor_indexとhover_indexが別々に設定される
    renderer, colors = make_renderer_with_color_spy
    renderer.draw_bars([5] * 5, 1, 3)
    expected = [CanvasRenderer::BAR_COLOR, CanvasRenderer::CURSOR_COLOR,
                CanvasRenderer::BAR_COLOR, CanvasRenderer::HOVER_COLOR, CanvasRenderer::BAR_COLOR]
    assert_equal expected, colors
  end
end
