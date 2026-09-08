class CreateSkillAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :skill_attempts do |t|
      t.string :external_id, null: false
      t.datetime :recorded_at, null: false
      t.datetime :run_started_at
      t.integer :sequence
      t.string :character_name
      t.string :character_serial
      t.string :skill, null: false
      t.string :subject, null: false
      t.decimal :skill_from, precision: 4, scale: 1, null: false
      t.decimal :skill_to, precision: 4, scale: 1, null: false
      t.string :outcome, null: false

      t.timestamps
    end
    add_index :skill_attempts, :external_id, unique: true
    add_index :skill_attempts, :recorded_at
    add_index :skill_attempts, [ :skill, :skill_from ]
    add_index :skill_attempts, [ :skill, :subject ]
    add_index :skill_attempts, [ :character_serial, :run_started_at ]
  end
end
