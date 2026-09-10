class SkillStatsController < ApplicationController
  def show
    @form = SkillRangeForm.new(params.permit(:skill, :from, :to, :subject).compact_blank)
    @stats = SkillAttempts::RangeStats.call(**@form.to_query) if @form.filled? && @form.valid?
  end
end
