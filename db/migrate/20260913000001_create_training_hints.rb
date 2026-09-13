class CreateTrainingHints < ActiveRecord::Migration[8.1]
  def change
    create_table :training_hints do |t|
      t.string :skill, null: false
      t.text :body, null: false

      t.timestamps
    end
    add_index :training_hints, :skill
  end
end
