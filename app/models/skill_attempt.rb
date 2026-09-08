class SkillAttempt < ApplicationRecord
  has_many :consumed_materials, dependent: :destroy

  enum :skill, {
    blacksmithy: "Blacksmithy",
    bowcraft_fletching: "Bowcraft/Fletching",
    mysticism: "Mysticism",
    magery: "Magery",
    tailoring: "Tailoring",
    tinkering: "Tinkering"
  }, validate: true

  enum :outcome, {
    made: "made",
    failed: "failed",
    cast: "cast",
    fizzled: "fizzled"
  }, validate: true

  SUCCESSFUL_OUTCOMES = %w[made cast].freeze

  validates :external_id, presence: true, uniqueness: true
  validates :recorded_at, :skill_from, :skill_to, :subject, presence: true

  scope :successful, -> { where(outcome: SUCCESSFUL_OUTCOMES) }
  scope :unsuccessful, -> { where.not(outcome: SUCCESSFUL_OUTCOMES) }

  def success?
    outcome.in?(SUCCESSFUL_OUTCOMES)
  end
end
