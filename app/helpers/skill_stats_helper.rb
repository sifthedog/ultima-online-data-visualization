module SkillStatsHelper
  HINTS = {
    covered_steps: "A step is a 0.1 skill-gain increment (e.g. 31.0 → 31.1). It's covered once at least one recorded attempt raised skill at that step (a row that climbed more than 0.1 covers every step it passed); the figures below only use covered steps.",
    uncovered_ranges: "Consecutive runs of steps where no attempt ever raised skill. They're excluded from the estimate below rather than guessed at.",
    yield_coverage: "Gathering happens on every swing, not just ones that raise skill, so gathered-material figures use this broader swing coverage instead of the skill-gain coverage above.",
    expected_attempts: "Sum of attempts ÷ gains for every covered step — the estimated attempts needed to travel each covered step once.",
    attempts_per_point: "Expected attempts divided by covered skill points (covered steps ÷ 10) — the average attempts needed per 1.0 point, over covered ground only.",
    success_rate: "Share of attempts whose action itself succeeded (item made, spell cast, ore dug, etc). This is about the action outcome, not whether it raised skill.",
    uncovered_attempts: "Attempts made on steps that never recorded a skill gain. They can't be priced into the estimate above, so they're counted separately here.",
    material_total_consumed: "Expected quantity needed to travel the covered range once, based on how much was consumed per skill gain at each covered step.",
    material_per_point_consumed: "Expected quantity divided by covered skill points — the average amount used per 1.0 point of progress.",
    material_total_gathered: "Expected quantity picked up making one swing at every step that recorded a swing, not just ones that raised skill.",
    material_per_swing_gathered: "Expected quantity divided by swing-covered steps — the average amount gathered per single swing.",
    chart_points: "Each bar sums attempts ÷ gains over a whole skill point's covered steps. Faded bars are scaled up from a partially covered point, so treat them as rougher estimates.",
    subject_column: "What was being made, cast, dug, or smelted for this row's attempts (e.g. bow vs crossbow).",
    attempts_column: "Raw count of recorded skill-attempt rows for this subject within the selected range.",
    coverage: "Share of steps with at least one recorded skill gain. Only covered steps feed into the expected-attempts estimate."
  }.freeze

  def hint_for(key, align: :left) = render("skill_stats/hint", text: HINTS.fetch(key), align:)

  # The two material sections on the headline (consumed and gathered) render identically,
  # differing only in which summary fields and copy they pull from.
  def material_sections(summary)
    [
      {
        totals: summary.consumption, average: summary.average_consumption,
        total_hint: :material_total_consumed, total_caption: "for the covered range",
        rate_label_suffix: "per skill point", rate_hint: :material_per_point_consumed,
        rate_caption: "average over covered points"
      },
      {
        totals: summary.gathered, average: summary.average_yield,
        total_hint: :material_total_gathered, total_caption: "gathered in the covered range",
        rate_label_suffix: "per swing", rate_hint: :material_per_swing_gathered,
        rate_caption: "average over swing-covered steps"
      }
    ]
  end

  # 965 -> "96.5"
  def skill_level(tenths) = format("%.1f", tenths / 10.0)

  # 965, 970 -> "96.5–97.0"
  def skill_span(from_tenths, to_tenths) = "#{skill_level(from_tenths)}–#{skill_level(to_tenths)}"

  def count(value, precision: 1) = number_with_precision(value, precision:, delimiter: ",")

  def whole(value) = number_with_delimiter(value.round)

  def percent(ratio) = ratio.nil? ? "—" : number_to_percentage(ratio * 100, precision: 1)
end
