require "rails_helper"

RSpec.describe ConsumedMaterial do
  it "has a valid factory" do
    expect(build(:consumed_material)).to be_valid
  end

  it "belongs to an attempt and needs a name and quantity" do
    material = described_class.new

    expect(material).not_to be_valid
    expect(material.errors.attribute_names).to include(:skill_attempt, :name, :quantity)
  end

  it "joins back to its attempt" do
    attempt = create(:skill_attempt)
    material = create(:consumed_material, skill_attempt: attempt)

    expect(material.reload.skill_attempt).to eq(attempt)
  end

  it "defaults hue to 0 when the row does not say" do
    material = create(:skill_attempt).consumed_materials.create!(name: "regular boards", quantity: 7)

    expect(material.reload.hue).to eq(0)
  end
end
