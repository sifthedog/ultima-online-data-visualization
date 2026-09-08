class CreateConsumedMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :consumed_materials do |t|
      t.references :skill_attempt, null: false, foreign_key: true
      t.string :name, null: false
      t.string :graphic
      t.integer :hue, null: false, default: 0
      t.integer :quantity, null: false

      t.timestamps
    end
  end
end
