class SkillAttempt < ApplicationRecord
  has_many :consumed_materials, dependent: :destroy
  has_many :gathered_materials, dependent: :destroy

  enum :skill, {
    blacksmithy: "Blacksmithy",
    bowcraft_fletching: "Bowcraft/Fletching",
    mysticism: "Mysticism",
    magery: "Magery",
    tailoring: "Tailoring",
    inscription: "Inscription",
    tinkering: "Tinkering",
    mining: "Mining",
    alchemy: "Alchemy",
    carpentry: "Carpentry",
    lumberjacking: "Lumberjacking",
    hiding: "Hiding",
    spellweaving: "Spellweaving"
  }, validate: true

  enum :outcome, {
    made: "made",
    failed: "failed",
    cast: "cast",
    fizzled: "fizzled",
    dug: "dug",
    smelted: "smelted",
    chopped: "chopped",
    converted: "converted",
    hidden: "hidden"
  }, validate: true

  enum :gain_path, { legacy: "Legacy", modern: "Modern", perilous: "Perilous" }, validate: true

  SUCCESSFUL_OUTCOMES = %w[made cast dug smelted chopped converted hidden].freeze
  SKILL_ALIASES = { "Bowcraft" => "Bowcraft/Fletching", "Fletching" => "Bowcraft/Fletching" }.freeze

  def self.normalize_skill(name) = SKILL_ALIASES.fetch(name, name)

  validates :external_id, presence: true, uniqueness: true
  validates :recorded_at, :skill_from, :subject, presence: true

  scope :successful, -> { where(outcome: SUCCESSFUL_OUTCOMES) }
  scope :unsuccessful, -> { where.not(outcome: SUCCESSFUL_OUTCOMES) }

  def success?
    outcome.in?(SUCCESSFUL_OUTCOMES)
  end
end
