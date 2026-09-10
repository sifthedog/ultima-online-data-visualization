module SkillStatsChartHelper
  WIDTH = 1000
  HEIGHT = 280
  PLOT = { x: 48, y: 16, w: 944, h: 220 }.freeze
  Y_TICKS = 4

  # Geometry for the expected-attempts-per-point bar chart, so the SVG template stays declarative.
  def chart_layout(points)
    y_max = nice_ceiling(points.filter_map(&:scaled).max.to_f)
    slot = PLOT[:w].fdiv(points.size)
    bar_w = [ slot - 2, 24 ].min.clamp(1, slot)
    baseline = PLOT[:y] + PLOT[:h]

    bars = points.each_with_index.map do |point, index|
      slot_x = PLOT[:x] + index * slot
      height = point.scaled && y_max.positive? ? point.scaled / y_max * PLOT[:h] : 0

      {
        point:,
        slot_x:, slot_w: slot,
        x: slot_x + (slot - bar_w) / 2, w: bar_w,
        y: baseline - height, h: height,
        label: (skill_level(point.point * 10) if (point.point % 10).zero?),
        title: chart_title(point)
      }
    end

    ticks = (0..Y_TICKS).map do |index|
      value = y_max * index / Y_TICKS
      { value:, y: baseline - PLOT[:h] * index / Y_TICKS, label: whole(value) }
    end

    { width: WIDTH, height: HEIGHT, plot: PLOT, baseline:, y_max:, bars:, ticks: }
  end

  private

  def chart_title(point)
    span = skill_span(point.point * 10, (point.point + 1) * 10)
    return "#{span}: no data" if point.covered_steps.zero?

    detail = "#{point.covered_steps} of #{point.steps_in_range} steps"
    detail = "scaled from #{detail}" if point.partial
    "#{span}: #{count(point.scaled)} attempts (#{detail})"
  end

  # Smallest 1, 2 or 5 × 10^k at or above value.
  def nice_ceiling(value)
    return 1.0 if value <= 0

    magnitude = 10.0**Math.log10(value).floor
    [ 1, 2, 5, 10 ].map { |step| step * magnitude }.find { |candidate| candidate >= value }
  end
end
