module TrainingHints
  class Importer
    include Utils::Callable

    Result = Data.define(:imported, :problems)

    def initialize(path)
      @path = path
    end

    def call
      raise ArgumentError, "no such file: #{@path}" unless File.file?(@path)

      hints_by_label = JSON.parse(File.read(@path))
      raise ArgumentError, "#{@path}: expected an object of skill => [hints]" unless hints_by_label.is_a?(Hash)

      problems = []
      hints_by_skill = {}
      hints_by_label.each do |label, hints|
        skill = SkillAttempt.normalize_skill(label)
        if !SkillAttempt.skills.value?(skill)
          problems << "unknown skill #{label.inspect}"
        elsif !hints.is_a?(Array) || hints.any? { |hint| !hint.is_a?(String) || hint.blank? }
          problems << "#{label}: expected a list of non-blank strings"
        else
          hints_by_skill[skill] = hints
        end
      end

      imported = TrainingHint.transaction do
        hints_by_skill.sum do |skill, hints|
          TrainingHint.where(skill:).delete_all
          TrainingHint.insert_all(hints.map { |body| { skill:, body: } }).rows.size
        end
      end
      Result.new(imported:, problems:)
    end
  end
end
