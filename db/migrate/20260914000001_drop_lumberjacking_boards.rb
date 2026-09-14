class DropLumberjackingBoards < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DELETE FROM gathered_materials USING skill_attempts
      WHERE gathered_materials.skill_attempt_id = skill_attempts.id
        AND skill_attempts.skill = 'Lumberjacking' AND gathered_materials.name LIKE '%boards'
    SQL
  end

  def down = nil
end
