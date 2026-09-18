class SkillRangeForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MIN = BigDecimal("0")
  MAX = BigDecimal("120")

  attribute :skill, :string
  attribute :from, :decimal, default: MIN
  attribute :to, :decimal, default: MAX
  attribute :gain_path, :string
  attribute :subjects, default: -> { [] }

  validates :skill, inclusion: { in: ->(_) { SkillAttempt.skills.keys }, message: "is not a known skill" }
  validates :from, :to, presence: true, numericality: { greater_than_or_equal_to: MIN, less_than_or_equal_to: MAX }
  validate :tenths_only, :ordered

  def filled? = skill.present?

  def from_tenths = tenths(from)
  def to_tenths = tenths(to)

  def skill_options = SkillAttempt.skills.map { |key, label| [ label, key ] }.sort_by { |label, _| label }

  def skill_label = SkillAttempt.skills[skill]

  def gain_path_options = SkillAttempt.gain_paths.map { |key, label| [ label, key ] }

  def chosen_gain_path = gain_path.presence_in(SkillAttempt.gain_paths.keys)

  def gain_path_label = SkillAttempt.gain_paths[chosen_gain_path]

  # Subject is free text, so the recorded values are the whitelist.
  def subject_options
    @subject_options ||= skill.present? ? SkillAttempt.where(skill:).distinct.order(:subject).pluck(:subject) : []
  end

  def chosen_subjects = @chosen_subjects ||= Array(subjects).compact_blank & subject_options

  def subjects_label = chosen_subjects.map(&:titleize).to_sentence

  def to_query = { skill:, from_tenths:, to_tenths:, gain_path: chosen_gain_path, subjects: chosen_subjects }

  private

  def tenths(value) = value && (value * 10).to_i

  def tenths_only
    { from:, to: }.each do |name, value|
      errors.add(name, "must be a multiple of 0.1") if value && (value * 10) % 1 != 0
    end
  end

  def ordered
    errors.add(:to, "must be greater than from") if from && to && from >= to
  end
end
