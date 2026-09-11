require "rails_helper"

RSpec.describe SkillAttempts::ChartLayout do
  def point(index, scaled:)
    SkillAttempts::RangeStats::Summary::Point.new(
      point: index, steps_in_range: 10, covered_steps: 10, expected: scaled, scaled:, partial: false, consumption: {}
    )
  end

  describe ".nice_ceiling" do
    it "floors non-positive values to 1.0" do
      expect(described_class.nice_ceiling(0)).to eq(1.0)
      expect(described_class.nice_ceiling(-5)).to eq(1.0)
    end

    it "rounds up to the nearest 1, 2 or 5 x 10^k" do
      expect(described_class.nice_ceiling(3)).to eq(5.0)
      expect(described_class.nice_ceiling(6)).to eq(10.0)
    end

    it "leaves an exact power of 10 unchanged" do
      expect(described_class.nice_ceiling(100)).to eq(100.0)
    end
  end

  describe "#call" do
    it "clamps the bar width between 1 and the slot width when slots are narrow" do
      points = (1..200).map { |i| point(i, scaled: 10) }

      layout = described_class.call(points)

      expect(layout[:bars]).to all(satisfy { |bar| bar[:w].between?(1, bar[:slot_w]) })
    end

    it "caps the bar width at 24 when slots are wide" do
      points = [ point(1, scaled: 10), point(2, scaled: 20) ]

      layout = described_class.call(points)

      expect(layout[:bars]).to all(satisfy { |bar| bar[:w] <= 24 })
    end

    it "draws no bar height for points with no scaled value" do
      layout = described_class.call([ point(1, scaled: nil) ])

      expect(layout[:bars].sole[:h]).to eq(0)
    end
  end
end
