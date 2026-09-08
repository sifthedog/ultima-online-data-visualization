class ConsumedMaterial < ApplicationRecord
  belongs_to :skill_attempt

  validates :name, presence: true
  validates :quantity, presence: true
end
