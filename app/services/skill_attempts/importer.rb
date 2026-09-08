module SkillAttempts
  class Importer
    include Utils::Callable

    DEFAULT_PATH = File.expand_path("~/Downloads/TazUO-Launcher.osx-arm64/TazUO/skill-attempts.jsonl")
    VERSION = 1
    REQUIRED = %w[id t skill from to outcome used].freeze
    BATCH_SIZE = 1000
    SKILL_ALIASES = { "Bowcraft" => "Bowcraft/Fletching", "Fletching" => "Bowcraft/Fletching" }.freeze

    Result = Data.define(:imported, :skipped, :problems)
    class Skipped < StandardError; end

    def initialize(path)
      @path = path
    end

    def call
      raise ArgumentError, "no such file: #{@path}" unless File.file?(@path)

      problems = []
      rows = File.foreach(@path).with_index(1).filter_map do |text, number|
        parse(text) unless text.strip.empty?
      rescue Skipped => error
        problems << "#{@path}:#{number}: #{error.message}"
        nil
      end
      rows.uniq! { |row| row["id"] }

      imported = SkillAttempt.transaction { rows.each_slice(BATCH_SIZE).sum { |batch| insert(batch) } }
      Result.new(imported:, skipped: rows.size - imported, problems:)
    end

    private

    def parse(text)
      row = JSON.parse(text)
      raise Skipped, "not an object" unless row.is_a?(Hash)
      raise Skipped, "version #{row['v'].inspect}, this reads version #{VERSION}" unless row["v"] == VERSION

      missing = REQUIRED.select { |name| row[name].nil? }
      raise Skipped, "no #{missing.join(', ')}" if missing.any?

      row["skill"] = SKILL_ALIASES.fetch(row["skill"], row["skill"])
      raise Skipped, "unknown skill #{row['skill'].inspect}" unless SkillAttempt.skills.value?(row["skill"])
      raise Skipped, "unknown outcome #{row['outcome'].inspect}" unless SkillAttempt.outcomes.value?(row["outcome"])

      row
    rescue JSON::ParserError => error
      raise Skipped, "not JSON (#{error.message})"
    end

    def insert(rows)
      now = Time.current
      by_id = rows.index_by { |row| row["id"] }
      inserted = SkillAttempt.insert_all(rows.map { |row| attempt_attributes(row, now) }, returning: %w[id external_id])
      consumed = inserted.rows.flat_map { |id, external_id| consumed_attributes(by_id.fetch(external_id), id, now) }
      ConsumedMaterial.insert_all(consumed) if consumed.any?
      inserted.rows.size
    end

    def attempt_attributes(row, now)
      _serial, run_ms, sequence = row["id"].split("/")

      {
        external_id: row["id"],
        recorded_at: Time.at(row["t"]).utc,
        run_started_at: run_ms && Time.at(run_ms.to_i / 1000.0).utc,
        sequence: sequence&.to_i,
        character_name: row["char"].to_s,
        character_serial: row["serial"].to_s,
        skill: row["skill"],
        skill_from: row["from"],
        skill_to: row["to"],
        outcome: row["outcome"],
        subject: row["used"],
        created_at: now,
        updated_at: now
      }
    end

    def consumed_attributes(row, attempt_id, now)
      Array(row["consumed"]).map do |spent|
        {
          skill_attempt_id: attempt_id,
          name: spent["name"].to_s,
          graphic: spent["graphic"],
          hue: spent["hue"] || 0,
          quantity: spent["qty"] || 0,
          created_at: now,
          updated_at: now
        }
      end
    end
  end
end
