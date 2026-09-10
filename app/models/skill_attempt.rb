class SkillAttempt < ApplicationRecord
  has_many :consumed_materials, dependent: :destroy
  has_many :gathered_materials, dependent: :destroy

  enum :skill, {
    blacksmithy: "Blacksmithy",
    bowcraft_fletching: "Bowcraft/Fletching",
    mysticism: "Mysticism",
    magery: "Magery",
    tailoring: "Tailoring",
    tinkering: "Tinkering",
    mining: "Mining"
  }, validate: true

  enum :outcome, {
    made: "made",
    failed: "failed",
    cast: "cast",
    fizzled: "fizzled",
    dug: "dug",
    smelted: "smelted"
  }, validate: true

  SUCCESSFUL_OUTCOMES = %w[made cast dug smelted].freeze

  validates :external_id, presence: true, uniqueness: true
  validates :recorded_at, :skill_from, :skill_to, :subject, presence: true

  scope :successful, -> { where(outcome: SUCCESSFUL_OUTCOMES) }
  scope :unsuccessful, -> { where.not(outcome: SUCCESSFUL_OUTCOMES) }

  def success?
    outcome.in?(SUCCESSFUL_OUTCOMES)
  end
end
