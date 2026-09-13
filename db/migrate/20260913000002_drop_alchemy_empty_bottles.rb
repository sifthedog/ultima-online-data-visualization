class DropAlchemyEmptyBottles < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DELETE FROM consumed_materials USING skill_attempts
      WHERE consumed_materials.skill_attempt_id = skill_attempts.id
        AND skill_attempts.skill = 'Alchemy' AND consumed_materials.name = 'empty bottles'
    SQL
  end

  def down = nil
end
