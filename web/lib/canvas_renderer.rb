require "js"

class CanvasRenderer
  BACKGROUND_COLOR = "#0B1020"
  BAR_COLOR        = "#66CCFF"
  CURSOR_COLOR     = "#FFD166"
  AXIS_COLOR       = "#DDDDDD"
  LABEL_BG_COLOR   = "#FFFFFF"
  LABEL_FG_COLOR   = "#111111"
  AXIS_HEIGHT      = 28
  BAR_BOTTOM_PAD   = 5

  def initialize(canvas, start_hz:, step_hz:, channel_count:)
    @canvas        = canvas
    @width         = canvas[:width].to_i
    @height        = canvas[:height].to_i
    @ctx           = canvas.call(:getContext, "2d")
    @start_hz      = start_hz
    @step_hz       = step_hz
    @channel_count = channel_count
  end

  def clear
    @ctx[:fillStyle] = BACKGROUND_COLOR
    @ctx.call(:fillRect, 0, 0, @width, @height)
  end

  def draw_axis(mhz_marks = [76, 80, 85, 90, 95])
    @ctx[:strokeStyle] = AXIS_COLOR
    @ctx[:fillStyle]   = AXIS_COLOR
    @ctx[:font]        = "12px monospace"

    @ctx.call(:beginPath)
    @ctx.call(:moveTo, 0, AXIS_HEIGHT)
    @ctx.call(:lineTo, @width, AXIS_HEIGHT)
    @ctx.call(:stroke)

    last_index = @channel_count - 1

    mhz_marks.each do |mhz|
      ch_index = ((mhz * 1_000_000) - @start_hz) / @step_hz
      next if ch_index < 0 || ch_index > last_index

      x = ch_center_x(ch_index)
      @ctx.call(:beginPath)
      @ctx.call(:moveTo, x, AXIS_HEIGHT - 4)
      @ctx.call(:lineTo, x, AXIS_HEIGHT + 4)
      @ctx.call(:stroke)

      if ch_index == 0
        @ctx[:textAlign] = "left"
        label_x = 2
      elsif ch_index == last_index
        @ctx[:textAlign] = "right"
        label_x = @width - 2
      else
        @ctx[:textAlign] = "center"
        label_x = x
      end
      @ctx.call(:fillText, "#{mhz} MHz", label_x, 20)
    end
  end

  def draw_bars(rssi_array, cursor_index = nil)
    bar_area_h = @height - AXIS_HEIGHT - BAR_BOTTOM_PAD
    rssi_array.each_with_index do |rssi, i|
      x = ch_left_x(i)
      h = (rssi.to_f / 15.0) * bar_area_h
      y = @height - h - BAR_BOTTOM_PAD
      @ctx[:fillStyle] = (i == cursor_index ? CURSOR_COLOR : BAR_COLOR)
      w = [bar_width - 0.6, 1.0].max
      @ctx.call(:fillRect, x, y, w, h)
    end
  end

  def draw_station_labels(labels)
    @ctx[:font]      = "11px sans-serif"
    @ctx[:textAlign] = "center"

    placed = place_labels(labels)

    placed.each do |p|
      label_y = AXIS_HEIGHT + 10 + p[:row] * 20
      @ctx[:fillStyle] = LABEL_BG_COLOR
      @ctx.call(:fillRect, p[:x] - p[:box_w] / 2, label_y, p[:box_w], 16)
      @ctx[:fillStyle] = LABEL_FG_COLOR
      @ctx.call(:fillText, p[:name], p[:x], label_y + 12)
    end
  end

  private

  LABEL_ROW_COUNT = 2
  LABEL_HORIZONTAL_GAP = 4

  def place_labels(labels)
    row_right = Array.new(LABEL_ROW_COUNT)
    sorted = labels.sort_by { |l| l[:ch_index] }

    sorted.map do |label|
      x = ch_center_x(label[:ch_index])
      text_width = @ctx.call(:measureText, label[:name])[:width].to_f
      box_w = text_width + 14
      left = x - box_w / 2

      row = LABEL_ROW_COUNT - 1
      LABEL_ROW_COUNT.times do |r|
        if row_right[r].nil? || left >= row_right[r] + LABEL_HORIZONTAL_GAP
          row = r
          break
        end
      end
      row_right[row] = x + box_w / 2

      { name: label[:name], x: x, box_w: box_w, row: row }
    end
  end

  def bar_width
    @width.to_f / @channel_count
  end

  def ch_left_x(ch_index)
    ch_index * bar_width
  end

  def ch_center_x(ch_index)
    ch_left_x(ch_index) + bar_width / 2
  end
end