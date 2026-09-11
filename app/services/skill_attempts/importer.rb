module SkillAttempts
  class Importer
    include Utils::Callable

    DEFAULT_PATH = File.expand_path("~/Downloads/TazUO-Launcher.osx-arm64/TazUO/skill-attempts.jsonl")
    VERSION = 1
    # "to" is not required: the recorder writes null there when the client had stopped answering
    REQUIRED = %w[id t skill from outcome used].freeze
    BATCH_SIZE = 1000

    Result = Data.define(:imported, :skipped, :problems)
    class Skipped < StandardError; end

    # The client only names a metal in an ore tooltip; ingots (and the rare ore miss) come back as
    # a bare "Ingots"/"ore", identifiable only by hue. Iron is hue 0 and reads with no metal prefix
    # in-game (plain "Ingots"), so it's left alone here too.
    INGOT_METAL_HUES = {
      2207 => "verite", 2213 => "golden", 2219 => "valorite",
      2406 => "shadow iron", 2413 => "copper", 2418 => "bronze", 2419 => "dull copper"
    }.freeze
    GENERIC_RESOURCE_NAMES = %w[ore ingots].freeze

    # Stacked items report their client tooltip as their name (e.g. "1082 Ingots"), which bakes
    # the stack size into the name; ore is unaffected because Legion resolves its name itself.
    def self.normalize_material_name(name, hue: 0)
      normalized = name.to_s.sub(/\A\d[\d,]*\s+/, "").downcase
      return normalized unless GENERIC_RESOURCE_NAMES.include?(normalized)

      metal = INGOT_METAL_HUES[hue.to_i]
      return "#{metal} #{normalized}" if metal
      # A bare "ore" is a tooltip read that came back with no metal line, which Legion treats as
      # plain iron (see its metal.py) rather than a metal of its own, so it isn't its own bucket.
      return "iron ore" if normalized == "ore"

      normalized
    end

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

      row["skill"] = SkillAttempt.normalize_skill(row["skill"])
      raise Skipped, "unknown skill #{row['skill'].inspect}" unless SkillAttempt.skills.value?(row["skill"])
      raise Skipped, "unknown outcome #{row['outcome'].inspect}" unless SkillAttempt.outcomes.value?(row["outcome"])

      row
    rescue JSON::ParserError => error
      raise Skipped, "not JSON (#{error.message})"
    end

    def insert(rows)
      by_id = rows.index_by { |row| row["id"] }
      # insert_all defaults to on_duplicate: :skip, so re-importing a file whose rows already
      # exist (by the unique external_id index) is a no-op for those rows rather than an error.
      inserted = SkillAttempt.insert_all(rows.map { |row| attempt_attributes(row) }, returning: %w[id external_id])

      consumed = []
      gathered = []
      inserted.rows.each do |id, external_id|
        row = by_id.fetch(external_id)
        consumed.concat(material_attributes(row, id, "consumed"))
        gathered.concat(material_attributes(row, id, "gained"))
      end

      ConsumedMaterial.insert_all(consumed) if consumed.any?
      GatheredMaterial.insert_all(gathered) if gathered.any?
      inserted.rows.size
    end

    def attempt_attributes(row)
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
        subject: row["used"]
      }
    end

    def material_attributes(row, attempt_id, key)
      Array(row[key]).map do |item|
        {
          skill_attempt_id: attempt_id,
          name: self.class.normalize_material_name(item["name"], hue: item["hue"] || 0),
          graphic: item["graphic"],
          hue: item["hue"] || 0,
          quantity: item["qty"] || 0
        }
      end
    end
  end
end
