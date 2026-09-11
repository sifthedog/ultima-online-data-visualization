module SkillStatsChartHelper
  def chart_layout(points)
    layout = SkillAttempts::ChartLayout.call(points)

    layout.merge(
      bars: layout[:bars].map { |bar| bar.merge(label: bar_label(bar[:point]), title: chart_title(bar[:point])) },
      ticks: layout[:ticks].map { |tick| tick.merge(label: whole(tick[:value])) }
    )
  end

  private

  def bar_label(point)
    skill_level(point.point * 10) if (point.point % 10).zero?
  end

  def chart_title(point)
    span = skill_span(point.point * 10, (point.point + 1) * 10)
    return "#{span}: no data" if point.covered_steps.zero?

    detail = "#{point.covered_steps} of #{point.steps_in_range} steps"
    return "#{span}: too few covered steps to estimate (#{detail})" if point.scaled.nil?

    detail = "scaled from #{detail}" if point.partial
    "#{span}: #{count(point.scaled)} attempts (#{detail})"
  end
end
