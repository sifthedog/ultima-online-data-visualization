module SkillAttempts
  # Aggregates attempts and consumed materials for one skill over a [from, to) range,
  # pooled per 0.1 step so overlapping macro runs are not double counted.
  class RangeStats
    include Utils::Callable

    StepTally = Data.define(:step, :attempts, :gains, :successes, :quantities, :gathered_quantities) do
      def self.blank(step) = new(step:, attempts: 0, gains: 0, successes: 0, quantities: {}, gathered_quantities: {})

      def +(other)
        with(
          attempts: attempts + other.attempts,
          gains: gains + other.gains,
          successes: successes + other.successes,
          quantities: quantities.merge(other.quantities) { |_, mine, theirs| mine + theirs },
          gathered_quantities: gathered_quantities.merge(other.gathered_quantities) { |_, mine, theirs| mine + theirs }
        )
      end
    end

    Result = Data.define(:skill, :from_tenths, :to_tenths, :subject, :summary, :by_subject, :tiers)

    # One subject's unbroken run of consecutive skill points: `summary` is recomputed over the
    # run's own [from_tenths, to_tenths) so its per-point rates reflect that stretch alone, and
    # `points` holds the same run's individual Summary::Point values for the expanded view.
    Tier = Data.define(:subject, :from_tenths, :to_tenths, :summary, :points)

    STEP = Arel.sql("(skill_attempts.skill_from * 10)::integer")
    GAINED_STEP = Arel.sql("gained.step")

    def initialize(skill:, from_tenths:, to_tenths:, subject: nil)
      @skill = skill
      @from_tenths = from_tenths
      @to_tenths = to_tenths
      @subject = subject.presence
    end

    def call
      by_subject = tallies_by_subject.transform_values { |tallies| summarize(tallies.transform_values { |tally| [ tally ] }) }
      pooled = tallies_by_subject.values.flat_map(&:values).group_by(&:step)
      subject_summaries = @subject ? {} : by_subject.sort_by { |_, summary| -summary.attempts }.to_h

      Result.new(
        skill: @skill, from_tenths: @from_tenths, to_tenths: @to_tenths, subject: @subject,
        summary: summarize(pooled),
        by_subject: subject_summaries,
        tiers: subject_summaries.empty? ? [] : tiers(subject_summaries)
      )
    end

    private

    def summarize(tallies, from_tenths: @from_tenths, to_tenths: @to_tenths) = Summary.new(tallies, from_tenths:, to_tenths:)

    # Each subject's unbroken runs of consecutive skill points it had a gain in, oldest first.
    def tiers(subject_summaries)
      subject_summaries.flat_map do |subject, subject_summary|
        wrapped_tallies = tallies_by_subject[subject].transform_values { |tally| [ tally ] }

        consecutive_runs(subject_summary.points).map do |run|
          from_tenths = run.first.point * Summary::STEPS_PER_POINT
          to_tenths = (run.last.point + 1) * Summary::STEPS_PER_POINT

          Tier.new(subject:, from_tenths:, to_tenths:, points: run, summary: summarize(wrapped_tallies, from_tenths:, to_tenths:))
        end
      end.sort_by(&:from_tenths)
    end

    def consecutive_runs(points)
      points.select { |point| point.covered_steps.positive? }.slice_when { |a, b| b.point != a.point + 1 }.to_a
    end

    def tallies_by_subject
      @tallies_by_subject ||= begin
        tallies = Hash.new { |hash, subject| hash[subject] = {} }

        attempts.each do |subject, step, count, successes|
          tallies[subject][step] = StepTally.new(step:, attempts: count, gains: 0, successes:, quantities: {}, gathered_quantities: {})
        end

        gains.each do |subject, step, count|
          tally = tallies[subject][step] ||= StepTally.blank(step)
          tallies[subject][step] = tally.with(gains: count)
        end

        materials.each do |subject, step, name, quantity|
          tally = tallies[subject][step] ||= StepTally.blank(step)
          tallies[subject][step] = tally.with(quantities: tally.quantities.merge(name => quantity))
        end

        gathered_materials.each do |subject, step, name, quantity|
          tally = tallies[subject][step] ||= StepTally.blank(step)
          tallies[subject][step] = tally.with(gathered_quantities: tally.gathered_quantities.merge(name => quantity))
        end

        tallies
      end
    end

    def by_skill
      relation = SkillAttempt.where(skill: @skill)
      @subject ? relation.where(subject: @subject) : relation
    end

    # Attempts belong to the step they were made at
    def scope
      by_skill.where(skill_from: (@from_tenths / 10.0)...(@to_tenths / 10.0))
    end

    def attempts
      successful = SkillAttempt::SUCCESSFUL_OUTCOMES.map { |outcome| SkillAttempt.connection.quote(outcome) }.join(", ")

      scope.group(:subject, STEP).pluck(
        :subject, STEP,
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) FILTER (WHERE skill_attempts.outcome IN (#{successful}))")
      )
    end

    # A gain belongs to every step it climbed through: a row that ends where the next attempt
    # started can span two steps when the shard applied the gain during a pause, and each of those
    # steps was passed exactly once. Filtered by the step, not the start, so a row that began just
    # below the range still credits the step inside it. A null end is an attempt with no gain.
    def gains
      by_skill
        .where("skill_attempts.skill_to > skill_attempts.skill_from")
        .joins(Arel.sql(<<~SQL.squish))
          CROSS JOIN LATERAL generate_series(
            (skill_attempts.skill_from * 10)::integer, (skill_attempts.skill_to * 10)::integer - 1
          ) AS gained(step)
        SQL
        .where("gained.step >= ? AND gained.step < ?", @from_tenths, @to_tenths)
        .group(:subject, GAINED_STEP)
        .pluck(:subject, GAINED_STEP, Arel.sql("COUNT(*)"))
    end

    def materials
      ConsumedMaterial.joins(:skill_attempt).merge(scope)
        .group("skill_attempts.subject", STEP, "consumed_materials.name")
        .pluck("skill_attempts.subject", STEP, "consumed_materials.name", Arel.sql("SUM(consumed_materials.quantity)"))
    end

    def gathered_materials
      GatheredMaterial.joins(:skill_attempt).merge(scope)
        .group("skill_attempts.subject", STEP, "gathered_materials.name")
        .pluck("skill_attempts.subject", STEP, "gathered_materials.name", Arel.sql("SUM(gathered_materials.quantity)"))
    end
  end
end
