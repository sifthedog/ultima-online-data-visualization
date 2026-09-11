module SkillAttempts
  # Geometry for the expected-attempts-per-point bar chart: bar/tick pixel positions and the
  # y-axis scale, so the SVG template and helper stay purely about rendering, not layout math.
  class ChartLayout
    include Utils::Callable

    WIDTH = 1000
    HEIGHT = 280
    PLOT = { x: 48, y: 16, w: 944, h: 220 }.freeze
    Y_TICKS = 4

    def initialize(points)
      @points = points
    end

    def call
      y_max = self.class.nice_ceiling(@points.filter_map(&:scaled).max.to_f)
      slot = PLOT[:w].fdiv(@points.size)
      bar_w = [ slot - 2, 24 ].min.clamp(1, slot)
      baseline = PLOT[:y] + PLOT[:h]

      bars = @points.each_with_index.map do |point, index|
        slot_x = PLOT[:x] + index * slot
        height = point.scaled && y_max.positive? ? point.scaled / y_max * PLOT[:h] : 0

        { point:, slot_x:, slot_w: slot, x: slot_x + (slot - bar_w) / 2, w: bar_w, y: baseline - height, h: height }
      end

      ticks = (0..Y_TICKS).map do |index|
        value = y_max * index / Y_TICKS
        { value:, y: baseline - PLOT[:h] * index / Y_TICKS }
      end

      { width: WIDTH, height: HEIGHT, plot: PLOT, baseline:, y_max:, bars:, ticks: }
    end

    # Smallest 1, 2 or 5 × 10^k at or above value.
    def self.nice_ceiling(value)
      return 1.0 if value <= 0

      magnitude = 10.0**Math.log10(value).floor
      [ 1, 2, 5, 10 ].map { |step| step * magnitude }.find { |candidate| candidate >= value }
    end
  end
end
