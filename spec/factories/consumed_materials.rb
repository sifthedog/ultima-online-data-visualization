FactoryBot.define do
  factory :consumed_material do
    skill_attempt
    name { "regular boards" }
    graphic { "0x1bd7" }
    hue { 0 }
    quantity { 7 }
  end
end
