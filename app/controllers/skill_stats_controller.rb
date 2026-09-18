class SkillStatsController < ApplicationController
  def show
    @form = SkillRangeForm.new(params.permit(:skill, :from, :to, :gain_path, subjects: []).compact_blank)
    return unless @form.filled? && @form.valid?

    @stats = SkillAttempts::RangeStats.call(**@form.to_query)
    @hints = TrainingHint.where(skill: @form.skill).order(:id)
  end
end
