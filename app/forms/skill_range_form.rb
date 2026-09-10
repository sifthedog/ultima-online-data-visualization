# Query parameters for the skill stats page: which skill, which [from, to) range, optional subject.
class SkillRangeForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MIN = BigDecimal("0")
  MAX = BigDecimal("120")

  attribute :skill, :string
  attribute :from, :decimal, default: MIN
  attribute :to, :decimal, default: MAX
  attribute :subject, :string

  validates :skill, inclusion: { in: ->(_) { SkillAttempt.skills.keys }, message: "is not a known skill" }
  validates :from, :to, presence: true, numericality: { greater_than_or_equal_to: MIN, less_than_or_equal_to: MAX }
  validate :tenths_only, :ordered

  def filled? = skill.present?

  def from_tenths = tenths(from)
  def to_tenths = tenths(to)

  def skill_options = SkillAttempt.skills.map { |key, label| [ label, key ] }

  def skill_label = SkillAttempt.skills[skill]

  def subject_options
    return [] unless SkillAttempt.skills.key?(skill.to_s)

    @subject_options ||= SkillAttempt.where(skill:).distinct.order(:subject).pluck(:subject)
  end

  # A subject left over from a previously chosen skill is ignored rather than rejected.
  def chosen_subject = subject.presence_in(subject_options)

  def to_query = { skill:, from_tenths:, to_tenths:, subject: chosen_subject }

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
