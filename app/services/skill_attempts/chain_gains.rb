module SkillAttempts
  # Raises a row's end to the next row's start within its run, backfilling rows recorded before
  # the recorder did this itself. Only ever raises the end, so running it again changes nothing.
  class ChainGains
    include Utils::Callable

    SQL = <<~SQL.squish
      UPDATE skill_attempts
      SET skill_to = chained.next_from, updated_at = NOW()
      FROM (
        SELECT id, sequence,
               LEAD(skill_from) OVER run AS next_from,
               LEAD(sequence) OVER run AS next_sequence
        FROM skill_attempts
        WHERE run_started_at IS NOT NULL AND sequence IS NOT NULL
        WINDOW run AS (PARTITION BY character_serial, run_started_at ORDER BY sequence)
      ) AS chained
      WHERE skill_attempts.id = chained.id
        AND chained.next_sequence = chained.sequence + 1
        AND (skill_attempts.skill_to IS NULL OR chained.next_from > skill_attempts.skill_to)
    SQL

    def call
      SkillAttempt.connection.exec_update(SQL, "SkillAttempts::ChainGains")
    end
  end
end
