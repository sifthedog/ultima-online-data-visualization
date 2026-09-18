module SkillAttempts
  class Importer
    include Utils::Callable

    DEFAULT_PATH = File.expand_path("~/Downloads/TazUO-Launcher.osx-arm64/TazUO/LegionScripts/skill-attempts.jsonl")
    VERSION = 1
    # "to" is not required: the recorder writes null there when the client had stopped answering
    REQUIRED = %w[id t skill from outcome used].freeze
    BATCH_SIZE = 1000

    Result = Data.define(:imported, :skipped, :problems)
    class Skipped < StandardError; end

    # A bare "Ingots"/"ore"/"logs"/"boards" tooltip is identifiable only by hue; iron and plain
    # wood (hue 0) read with no prefix in-game, so they're left alone here too.
    RESOURCE_HUES = {
      2207 => "verite", 2213 => "golden", 2219 => "valorite",
      2406 => "shadow iron", 2413 => "copper", 2418 => "bronze", 2419 => "dull copper",
      1191 => "ash", 2010 => "oak"
    }.freeze
    GENERIC_RESOURCE_NAMES = %w[ore ingots logs boards].freeze
    # Legion names a chopped stack "Log", and a board stack whose tooltip never arrived by its graphic.
    RAW_NAMES = { "log" => "logs", "0x1bd7" => "boards" }.freeze
    # A gathering row's `used` is the tool, which says nothing about what was gathered, so these
    # skills name themselves by their yield instead. A swing that produced nothing falls back to
    # the generic noun it was after.
    GATHERING_FALLBACKS = { "Mining" => "ore", "Lumberjacking" => "logs" }.freeze

    # Stacked items report their client tooltip as their name (e.g. "1082 Ingots"), which bakes
    # the stack size into the name; ore is unaffected because Legion resolves its name itself.
    def self.normalize_material_name(name, hue: 0)
      normalized = name.to_s.sub(/\A\d[\d,]*\s+/, "").downcase
      normalized = RAW_NAMES.fetch(normalized, normalized)
      return normalized unless GENERIC_RESOURCE_NAMES.include?(normalized)

      kind = RESOURCE_HUES[hue.to_i]
      return "#{kind} #{normalized}" if kind
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

      row = row.transform_keys(&:underscore)
      raise Skipped, "version #{row['v'].inspect}, this reads version #{VERSION}" unless row["v"] == VERSION

      missing = REQUIRED.select { |name| row[name].nil? }
      raise Skipped, "no #{missing.join(', ')}" if missing.any?

      row["skill"] = SkillAttempt.normalize_skill(row["skill"])
      raise Skipped, "unknown skill #{row['skill'].inspect}" unless SkillAttempt.skills.value?(row["skill"])
      raise Skipped, "unknown outcome #{row['outcome'].inspect}" unless SkillAttempt.outcomes.value?(row["outcome"])

      repair_misread_conversion(row)

      # The recorder writes null where the client never answered [SkillGainMode; Modern is the shard default.
      row["gain_path"] ||= "Modern"
      raise Skipped, "unknown gain path #{row['gain_path'].inspect}" unless SkillAttempt.gain_paths.value?(row["gain_path"])

      row
    rescue JSON::ParserError => error
      raise Skipped, "not JSON (#{error.message})"
    end

    # Cutting logs into boards destroys no wood, so a failed row that spent logs is one whose boards
    # reached the pack after the recorder had already read the change and called the attempt a loss.
    def repair_misread_conversion(row)
      return unless row["skill"] == "Lumberjacking" && row["outcome"] == "failed" && row["consumed"].present?

      row["outcome"] = "converted"
      # Cutting is 1:1, the ratio every well-recorded conversion shows. The boards are dropped from
      # the material tally either way; they exist here only to name the attempt.
      row["gained"] ||= row["consumed"].map { |item| item.merge("name" => "boards") }
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
        gain_path: row["gain_path"],
        subject: subject_for(row)
      }
    end

    def subject_for(row)
      return row["used"] unless GATHERING_FALLBACKS.key?(row["skill"])

      # The raw yield, not material_attributes: its board filter would leave conversions unnamed.
      produced = Array(row["gained"]).first
      return GATHERING_FALLBACKS.fetch(row["skill"]) unless produced

      self.class.normalize_material_name(produced["name"], hue: produced["hue"] || 0)
    end

    def material_attributes(row, attempt_id, key)
      Array(row[key]).filter_map do |item|
        name = self.class.normalize_material_name(item["name"], hue: item["hue"] || 0)
        # A potion's bottle is its container, not a reagent, so alchemy never counts it as spent.
        next if row["skill"] == "Alchemy" && name == "empty bottles"
        # Boards are chopped logs in another shape, cut by a conversion that never raises the skill,
        # so counting them would report the same wood a second time.
        next if row["skill"] == "Lumberjacking" && name.end_with?("boards")

        {
          skill_attempt_id: attempt_id,
          name:,
          graphic: item["graphic"],
          hue: item["hue"] || 0,
          quantity: item["qty"] || 0
        }
      end
    end
  end
end
