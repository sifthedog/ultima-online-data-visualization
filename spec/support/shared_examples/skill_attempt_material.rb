RSpec.shared_examples "a skill attempt material" do |factory:, association:, material_name:, attempt_traits: []|
  it "has a valid factory" do
    expect(build(factory)).to be_valid
  end

  it "belongs to an attempt and needs a name and quantity" do
    material = described_class.new

    expect(material).not_to be_valid
    expect(material.errors.attribute_names).to include(:skill_attempt, :name, :quantity)
  end

  it "joins back to its attempt" do
    attempt = create(:skill_attempt, *attempt_traits)
    material = create(factory, skill_attempt: attempt)

    expect(material.reload.skill_attempt).to eq(attempt)
  end

  it "defaults hue to 0 when the row does not say" do
    attempt = create(:skill_attempt, *attempt_traits)
    material = attempt.public_send(association).create!(name: material_name, quantity: 7)

    expect(material.reload.hue).to eq(0)
  end
end
