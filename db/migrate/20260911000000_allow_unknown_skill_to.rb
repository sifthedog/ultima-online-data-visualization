# The recorder writes the last row of a run with no end when the client has stopped answering by
# the time it closes; that row is still an attempt.
class AllowUnknownSkillTo < ActiveRecord::Migration[8.1]
  def change
    change_column_null :skill_attempts, :skill_to, true
  end
end
