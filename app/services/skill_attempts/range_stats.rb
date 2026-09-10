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

    Result = Data.define(:skill, :from_tenths, :to_tenths, :subject, :summary, :by_subject)

    STEP = Arel.sql("(skill_attempts.skill_from * 10)::integer")

    def initialize(skill:, from_tenths:, to_tenths:, subject: nil)
      @skill = skill
      @from_tenths = from_tenths
      @to_tenths = to_tenths
      @subject = subject.presence
    end

    def call
      by_subject = tallies_by_subject.transform_values { |tallies| summarize(tallies.transform_values { |tally| [ tally ] }) }
      pooled = tallies_by_subject.values.flat_map(&:values).group_by(&:step)

      Result.new(
        skill: @skill, from_tenths: @from_tenths, to_tenths: @to_tenths, subject: @subject,
        summary: summarize(pooled),
        by_subject: @subject ? {} : by_subject.sort_by { |_, summary| -summary.attempts }.to_h
      )
    end

    private

    def summarize(tallies) = Summary.new(tallies, from_tenths: @from_tenths, to_tenths: @to_tenths)

    def tallies_by_subject
      @tallies_by_subject ||= begin
        tallies = Hash.new { |hash, subject| hash[subject] = {} }

        attempts.each do |subject, step, count, gains, successes|
          tallies[subject][step] = StepTally.new(step:, attempts: count, gains:, successes:, quantities: {}, gathered_quantities: {})
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

    def scope
      relation = SkillAttempt.where(skill: @skill, skill_from: (@from_tenths / 10.0)...(@to_tenths / 10.0))
      @subject ? relation.where(subject: @subject) : relation
    end

    def attempts
      successful = SkillAttempt::SUCCESSFUL_OUTCOMES.map { |outcome| SkillAttempt.connection.quote(outcome) }.join(", ")

      scope.group(:subject, STEP).pluck(
        :subject, STEP,
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) FILTER (WHERE skill_attempts.skill_to > skill_attempts.skill_from)"),
        Arel.sql("COUNT(*) FILTER (WHERE skill_attempts.outcome IN (#{successful}))")
      )
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
