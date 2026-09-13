class AddGainPathToSkillAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :skill_attempts, :gain_path, :string, null: false, default: "Modern"
  end
end
