class TrainingHint < ApplicationRecord
  enum :skill, SkillAttempt.skills, validate: true

  validates :body, presence: true
end
