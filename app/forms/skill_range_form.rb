class SkillRangeForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MIN = BigDecimal("0")
  MAX = BigDecimal("120")

  attribute :skill, :string
  attribute :from, :decimal, default: MIN
  attribute :to, :decimal, default: MAX
  attribute :gain_path, :string

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

  def to_query = { skill:, from_tenths:, to_tenths:, gain_path: chosen_gain_path }

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
