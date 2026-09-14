class RepairMisreadLogConversions < ActiveRecord::Migration[8.1]
  def up
    # Boards equal to the logs spent, the 1:1 the successfully recorded conversions all show
    # (see SkillAttempts::Importer#repair_misread_conversion). Inserted before the outcome flips.
    execute <<~SQL
      INSERT INTO gathered_materials (skill_attempt_id, name, graphic, hue, quantity, created_at, updated_at)
      SELECT consumed_materials.skill_attempt_id, replace(consumed_materials.name, 'logs', 'boards'),
             '0x1bd7', consumed_materials.hue, consumed_materials.quantity, now(), now()
      FROM consumed_materials JOIN skill_attempts ON skill_attempts.id = consumed_materials.skill_attempt_id
      WHERE skill_attempts.skill = 'Lumberjacking' AND skill_attempts.outcome = 'failed'
    SQL

    execute <<~SQL
      UPDATE skill_attempts SET outcome = 'converted'
      WHERE skill = 'Lumberjacking' AND outcome = 'failed'
        AND id IN (SELECT skill_attempt_id FROM consumed_materials)
    SQL
  end

  def down = nil
end
