FactoryBot.define do
  factory :skill_attempt do
    sequence(:external_id) { |n| "0xabc/1000/#{n}" }
    recorded_at { Time.utc(2026, 9, 5, 10) }
    run_started_at { Time.utc(2026, 9, 5, 9, 59) }
    sequence(:sequence)
    character_name { "Kaldor" }
    character_serial { "0xabc" }
    skill { :bowcraft_fletching }
    skill_from { 31.1 }
    skill_to { 31.2 }
    outcome { :made }
    subject { "bow" }

    trait :failed do
      outcome { :failed }
    end

    trait :mysticism do
      skill { :mysticism }
      skill_from { 50.0 }
      skill_to { 50.0 }
      outcome { :cast }
      subject { "Nether Bolt" }
    end

    trait :fizzled do
      mysticism
      outcome { :fizzled }
    end

    trait :mining do
      skill { :mining }
      skill_from { 79.0 }
      skill_to { 79.1 }
      outcome { :dug }
      subject { "pickaxe" }
    end

    trait :smelted do
      mining
      skill_from { 79.1 }
      skill_to { 79.1 }
      outcome { :smelted }
      subject { "fire beetle" }
    end

    trait :lumberjacking do
      skill { :lumberjacking }
      skill_from { 10.5 }
      skill_to { 10.6 }
      outcome { :chopped }
      subject { "axe" }
    end

    trait :converted do
      lumberjacking
      skill_from { 10.7 }
      skill_to { 10.7 }
      outcome { :converted }
    end

    trait :hiding do
      skill { :hiding }
      skill_from { 42.4 }
      skill_to { 42.5 }
      outcome { :hidden }
      subject { "Hiding" }
    end

    trait :spellweaving do
      skill { :spellweaving }
      skill_from { 45.0 }
      skill_to { 45.1 }
      outcome { :cast }
      subject { "Arcane Circle" }
    end
  end
end
