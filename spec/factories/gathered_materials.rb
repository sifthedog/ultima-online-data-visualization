FactoryBot.define do
  factory :gathered_material do
    skill_attempt
    name { "iron ore" }
    graphic { "0x19b7" }
    hue { 0 }
    quantity { 2 }
  end
end
