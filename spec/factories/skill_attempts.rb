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
  end
end
