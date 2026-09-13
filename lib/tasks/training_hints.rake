namespace :training_hints do
  desc "Replace each listed skill's training hints from a JSON file ({ \"Mining\": [\"hint\", ...] })"
  task :import, [ :path ] => :environment do |_, args|
    abort "usage: training_hints:import[path/to/hints.json]" if args[:path].blank?
    abort "no such file: #{args[:path]}" unless File.file?(args[:path])

    result = TrainingHints::Importer.call(args[:path])

    result.problems.each { |problem| puts "skipped #{problem}" }
    puts "#{result.imported} hint(s) imported -> #{TrainingHint.count} total"
  end
end
