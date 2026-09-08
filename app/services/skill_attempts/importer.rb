require "json"

module SkillAttempts
  class Importer
    DEFAULT_PATH = File.expand_path("~/Downloads/TazUO-Launcher.osx-arm64/TazUO/skill-attempts.jsonl")
    VERSION = 1
    REQUIRED = %w[id t skill from to outcome used].freeze
    BATCH_SIZE = 1000

    SKILL_ALIASES = {
      "Bowcraft" => "Bowcraft/Fletching",
      "Fletching" => "Bowcraft/Fletching"
    }.freeze

    Result = Struct.new(:imported, :skipped, :problems, keyword_init: true)

    class Skipped < StandardError; end

    def initialize(path)
      @path = path
    end

    def call
      raise ArgumentError, "no such file: #{@path}" unless File.file?(@path)

      rows, problems = read_rows
      imported = 0
      skipped = 0

      SkillAttempt.transaction do
        rows.each_slice(BATCH_SIZE) do |batch|
          fresh = without_existing(batch)
          skipped += batch.size - fresh.size
          imported += insert(fresh)
        end
      end

      Result.new(imported: imported, skipped: skipped, problems: problems)
    end

    private

    def read_rows
      rows = []
      problems = []
      seen = Set.new

      File.foreach(@path).with_index(1) do |text, number|
        next if text.strip.empty?

        row = parse(text)
        next unless seen.add?(row["id"])

        rows << row
      rescue Skipped => error
        problems << "#{@path}:#{number}: #{error.message}"
      end

      [ rows, problems ]
    end

    def parse(text)
      row = JSON.parse(text)
      raise Skipped, "not an object" unless row.is_a?(Hash)

      version = row["v"]
      raise Skipped, "version #{version.inspect}, this reads version #{VERSION}" unless version == VERSION

      missing = REQUIRED.select { |name| row[name].nil? }
      raise Skipped, "no #{missing.join(', ')}" if missing.any?

      row["skill"] = SKILL_ALIASES.fetch(row["skill"], row["skill"])
      raise Skipped, "unknown skill #{row['skill'].inspect}" unless SkillAttempt.skills.value?(row["skill"])
      raise Skipped, "unknown outcome #{row['outcome'].inspect}" unless SkillAttempt.outcomes.value?(row["outcome"])

      row
    rescue JSON::ParserError => error
      raise Skipped, "not JSON (#{error.message})"
    end

    def without_existing(batch)
      existing = SkillAttempt.where(external_id: batch.map { |row| row["id"] }).pluck(:external_id).to_set

      batch.reject { |row| existing.include?(row["id"]) }
    end

    def insert(rows)
      return 0 if rows.empty?

      now = Time.current
      inserted = SkillAttempt.insert_all(rows.map { |row| attempt_attributes(row, now) }, returning: %w[id external_id])
      ids = inserted.rows.to_h { |id, external_id| [ external_id, id ] }

      consumed = rows.flat_map { |row| consumed_attributes(row, ids.fetch(row["id"]), now) }
      ConsumedMaterial.insert_all(consumed) if consumed.any?

      rows.size
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
