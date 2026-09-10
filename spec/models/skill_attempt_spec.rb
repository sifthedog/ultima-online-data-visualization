require "rails_helper"

RSpec.describe SkillAttempt do
  it "has a valid factory" do
    expect(build(:skill_attempt)).to be_valid
    expect(build(:skill_attempt, :failed)).to be_valid
    expect(build(:skill_attempt, :mysticism)).to be_valid
    expect(build(:skill_attempt, :fizzled)).to be_valid
    expect(build(:skill_attempt, :mining)).to be_valid
    expect(build(:skill_attempt, :smelted)).to be_valid
  end

  it "requires the columns the importer always fills" do
    attempt = described_class.new

    expect(attempt).not_to be_valid
    expect(attempt.errors.attribute_names).to include(
      :external_id, :recorded_at, :skill, :skill_from, :skill_to, :outcome, :subject
    )
  end

  it "stores skills and outcomes under the shard's own names" do
    attempt = create(:skill_attempt, :fizzled)

    expect(attempt.reload).to be_mysticism
    expect(attempt).to be_fizzled
    expect(described_class.skills.values).to contain_exactly(
      "Blacksmithy", "Bowcraft/Fletching", "Mysticism", "Magery", "Tailoring", "Tinkering", "Mining"
    )
    expect(described_class.outcomes.values).to contain_exactly("made", "failed", "cast", "fizzled", "dug", "smelted")
  end

  it "rejects a skill or outcome it has not been taught" do
    attempt = build(:skill_attempt, skill: "Taming", outcome: "tamed")

    expect(attempt).not_to be_valid
    expect(attempt.errors.attribute_names).to include(:skill, :outcome)
  end

  it "rejects a repeated external_id" do
    existing = create(:skill_attempt)

    copy = build(:skill_attempt, external_id: existing.external_id)

    expect(copy).not_to be_valid
    expect(copy.errors.attribute_names).to include(:external_id)
  end

  it "destroys its consumed materials" do
    attempt = create(:skill_attempt)
    create(:consumed_material, skill_attempt: attempt)

    expect { attempt.destroy }.to change(ConsumedMaterial, :count).by(-1)
  end

  it "destroys its gathered materials" do
    attempt = create(:skill_attempt, :mining)
    create(:gathered_material, skill_attempt: attempt)

    expect { attempt.destroy }.to change(GatheredMaterial, :count).by(-1)
  end

  describe "success" do
    let!(:made) { create(:skill_attempt) }
    let!(:failed) { create(:skill_attempt, :failed) }
    let!(:cast) { create(:skill_attempt, :mysticism) }
    let!(:fizzled) { create(:skill_attempt, :fizzled) }
    let!(:dug) { create(:skill_attempt, :mining) }
    let!(:smelted) { create(:skill_attempt, :smelted) }

    it "is what the shard called made, cast, dug, or smelted" do
      expect(made).to be_success
      expect(cast).to be_success
      expect(dug).to be_success
      expect(smelted).to be_success
      expect(failed).not_to be_success
      expect(fizzled).not_to be_success
    end

    it ".successful and .unsuccessful split the table the same way" do
      expect(described_class.successful).to contain_exactly(made, cast, dug, smelted)
      expect(described_class.unsuccessful).to contain_exactly(failed, fizzled)
    end

    it "enum scopes filter by skill" do
      expect(described_class.mysticism).to contain_exactly(cast, fizzled)
    end
  end
end
