module SkillAttempts
  # Within a run, a row ends where the next attempt started: the recorder writes rows that way now,
  # and this brings the rest in line - rows recorded before it did, whose end was read a cycle
  # after the attempt and missed a gain that landed during a pause, and rows whose end the client
  # never answered. An end is only ever raised to a value the file itself recorded next, so running
  # it again changes nothing.
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

    # Returns how many rows changed.
    def call
      SkillAttempt.connection.exec_update(SQL, "SkillAttempts::ChainGains")
    end
  end
end
