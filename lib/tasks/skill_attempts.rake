namespace :skill_attempts do
  desc "Import a Legion skill-attempts.jsonl (default: the TazUO copy in ~/Downloads)"
  task :import, [ :path ] => :environment do |_, args|
    path = args[:path].presence || SkillAttempts::Importer::DEFAULT_PATH

    abort "no such file: #{path}" unless File.file?(path)

    result = SkillAttempts::Importer.call(path)

    result.problems.each { |problem| puts "skipped #{problem}" }
    puts "#{result.imported} imported, #{result.skipped} already present -> #{SkillAttempt.count} total"
  end
end
