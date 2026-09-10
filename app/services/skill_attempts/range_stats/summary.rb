module SkillAttempts
  class RangeStats
    # Pure math over per-step tallies for a [from, to) range of skill, in integer tenths.
    #
    # A step X is the 0.1 gain that moves a character from X to X + 0.1. Each step holds one
    # tally per subject, pooled across every run and character, so per_step(X) = attempts / gains
    # is the expected number of attempts for that gain no matter how many macros passed through X.
    # Steps with no recorded gain are uncovered: they contribute nothing and are reported as gaps.
    class Summary
      STEPS_PER_POINT = 10

      Point = Data.define(:point, :steps_in_range, :covered_steps, :expected, :scaled, :partial)

      attr_reader :from_tenths, :to_tenths

      # tallies: Hash of step => Array of StepTally, one per subject.
      def initialize(tallies, from_tenths:, to_tenths:)
        @tallies = tallies.select { |step, _| step >= from_tenths && step < to_tenths }
        @all = @tallies.values.flatten
        @from_tenths = from_tenths
        @to_tenths = to_tenths
      end

      def total_steps = to_tenths - from_tenths
      def covered_steps = covered.size
      def covered_points = covered_steps.fdiv(STEPS_PER_POINT)
      def coverage_ratio = total_steps.zero? ? 0.0 : covered_steps.fdiv(total_steps)
      def empty? = @tallies.empty?

      # Steps that recorded at least one attempt, regardless of whether it raised skill. Gathered
      # yield (e.g. ore from a mining swing) happens on every attempt, not just ones that gain skill,
      # so it needs its own coverage notion independent of the gain-based `covered` used for consumption.
      def yield_covered_steps = yielded.size
      def yield_coverage_ratio = total_steps.zero? ? 0.0 : yield_covered_steps.fdiv(total_steps)

      def attempts = @all.sum(&:attempts)
      def successes = @all.sum(&:successes)
      def success_rate = attempts.zero? ? nil : successes.fdiv(attempts)

      def expected_attempts = covered.values.sum { |tally| per_step(tally) }

      # Attempts on steps that never recorded a gain; they cannot be priced, so they stay out of the estimate.
      def uncovered_attempts = @tallies.reject { |step, _| covered.key?(step) }.values.flatten.sum(&:attempts)
      def attempts_per_point = covered_steps.zero? ? nil : expected_attempts / covered_points

      # Expected materials, by name, to travel the covered part of the range once.
      def consumption
        @consumption ||= covered.values.each_with_object(Hash.new(0.0)) do |tally, totals|
          tally.quantities.each { |name, quantity| totals[name] += quantity.fdiv(tally.gains) }
        end.sort.to_h
      end

      # Expected materials, by name, per 1.0 skill point of covered range.
      def average_consumption
        return {} if covered_steps.zero?

        consumption.transform_values { |total| total / covered_points }
      end

      # Expected materials, by name, gathered while making one swing at every yield-covered step in the range.
      def gathered
        @gathered ||= yielded.values.each_with_object(Hash.new(0.0)) do |tally, totals|
          tally.gathered_quantities.each { |name, quantity| totals[name] += quantity.fdiv(tally.attempts) }
        end.sort.to_h
      end

      # Expected materials, by name, per single swing (attempt), averaged over yield-covered steps.
      def average_yield
        return {} if yield_covered_steps.zero?

        gathered.transform_values { |total| total / yield_covered_steps }
      end

      # Maximal runs of consecutive uncovered steps as [start_tenths, end_tenths_exclusive].
      def uncovered_ranges
        @uncovered_ranges ||= (from_tenths...to_tenths).reject { |step| covered.key?(step) }
          .slice_when { |previous, current| current != previous + 1 }
          .map { |run| [ run.first, run.last + 1 ] }
      end

      # One bucket per whole skill point in the range, for charting.
      def points
        @points ||= (from_tenths / STEPS_PER_POINT).upto((to_tenths - 1) / STEPS_PER_POINT).map do |point|
          first = [ point * STEPS_PER_POINT, from_tenths ].max
          last = [ (point + 1) * STEPS_PER_POINT, to_tenths ].min
          steps = (first...last).filter_map { |step| covered[step] }
          expected = steps.sum { |tally| per_step(tally) }
          scaled = steps.empty? ? nil : expected * (last - first) / steps.size

          Point.new(
            point:, steps_in_range: last - first, covered_steps: steps.size,
            expected:, scaled:, partial: steps.any? && steps.size < last - first
          )
        end
      end

      private

      # step => every subject's tally at that step merged into one, for steps with at least one gain.
      def covered
        @covered ||= @tallies.filter_map do |step, tallies|
          merged = tallies.reduce(:+)
          [ step, merged ] if merged.gains.positive?
        end.to_h
      end

      # step => every subject's tally at that step merged into one, for steps with at least one attempt.
      def yielded
        @yielded ||= @tallies.filter_map do |step, tallies|
          merged = tallies.reduce(:+)
          [ step, merged ] if merged.attempts.positive?
        end.to_h
      end

      def per_step(tally) = tally.attempts.fdiv(tally.gains)
    end
  end
end
