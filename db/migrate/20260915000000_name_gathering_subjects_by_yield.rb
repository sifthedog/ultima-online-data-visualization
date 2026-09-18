class NameGatheringSubjectsByYield < ActiveRecord::Migration[8.1]
  # Gathering rows were imported with the tool they used ("pickaxe", "fire beetle", "axe"), which
  # says nothing about what they gathered; they name themselves by their yield now.
  def up
    execute <<~SQL
      UPDATE skill_attempts SET subject = COALESCE(
        (SELECT gathered_materials.name FROM gathered_materials
           WHERE gathered_materials.skill_attempt_id = skill_attempts.id
           ORDER BY gathered_materials.id LIMIT 1),
        -- A conversion's boards were dropped by DropLumberjackingBoards; cutting is 1:1, so the
        -- logs it spent name it.
        (SELECT replace(consumed_materials.name, 'logs', 'boards') FROM consumed_materials
           WHERE consumed_materials.skill_attempt_id = skill_attempts.id
             AND skill_attempts.outcome = 'converted'
           ORDER BY consumed_materials.id LIMIT 1),
        CASE skill_attempts.skill WHEN 'Mining' THEN 'ore' ELSE 'logs' END)
      WHERE skill_attempts.skill IN ('Mining', 'Lumberjacking')
    SQL
  end

  def down = nil
end
