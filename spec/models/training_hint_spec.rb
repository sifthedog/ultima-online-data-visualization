require "rails_helper"

RSpec.describe TrainingHint do
  it "has a valid factory" do
    expect(build(:training_hint)).to be_valid
  end

  it "shares the attempt skills, stored under the shard's own names" do
    hint = create(:training_hint, skill: :mining)

    expect(hint.reload).to be_mining
    expect(hint.skill_before_type_cast).to eq("Mining")
    expect(described_class.skills).to eq(SkillAttempt.skills)
  end

  it "rejects a blank body or a skill it has not been taught" do
    hint = build(:training_hint, skill: "Taming", body: " ")

    expect(hint).not_to be_valid
    expect(hint.errors.attribute_names).to include(:skill, :body)
  end
end
