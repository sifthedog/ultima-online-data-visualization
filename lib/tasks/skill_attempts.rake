namespace :skill_attempts do
  desc "Import a Legion skill-attempts.jsonl (default: the TazUO copy in ~/Downloads)"
  task :import, [ :path ] => :environment do |_, args|
    path = args[:path].presence || SkillAttempts::Importer::DEFAULT_PATH

    abort "no such file: #{path}" unless File.file?(path)

    result = SkillAttempts::Importer.call(path)

    result.problems.each { |problem| puts "skipped #{problem}" }
    puts "#{result.imported} imported, #{result.skipped} already present -> #{SkillAttempt.count} total"

    Rake::Task["skill_attempts:chain_gains"].invoke
  end

  desc "Set each row's end to the next row's start within its run, where the file recorded them apart"
  task chain_gains: :environment do
    puts "#{SkillAttempts::ChainGains.call} row(s) now end where the attempt after them started"
  end

  desc "Re-normalize consumed/gathered material names imported before the naming fixes"
  task normalize_material_names: :environment do
    [ ConsumedMaterial, GatheredMaterial ].each do |klass|
      fixed = klass.find_each.sum do |material|
        normalized = SkillAttempts::Importer.normalize_material_name(material.name, hue: material.hue)
        next 0 if normalized == material.name

        material.update_column(:name, normalized)
        1
      end
      puts "#{fixed} #{klass.name.underscore.humanize.downcase}(s) normalized"
    end
  end
end
