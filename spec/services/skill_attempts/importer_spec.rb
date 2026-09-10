require "rails_helper"

RSpec.describe SkillAttempts::Importer do
  let(:path) { file_fixture("skill-attempts.jsonl").to_s }

  def import
    described_class.call(path)
  end

  it "imports every readable row once and reports the rest" do
    result = nil

    expect { result = import }.to change(SkillAttempt, :count).by(6)

    expect(result.imported).to eq(6)
    expect(result.skipped).to eq(0)
    expect(result.problems.size).to eq(7)
    expect(result.problems[0]).to eq("#{path}:4: no to")
    expect(result.problems[1]).to start_with("#{path}:6: not JSON (")
    expect(result.problems[2]).to eq("#{path}:7: version 2, this reads version 1")
    expect(result.problems[3]).to eq("#{path}:8: no from")
    expect(result.problems[4]).to eq("#{path}:9: unknown skill \"Taming\"")
    expect(result.problems[5]).to eq("#{path}:10: unknown outcome \"throttled\"")
    expect(result.problems[6]).to eq("#{path}:12: no used")
  end

  it "maps a bowcraft row with its materials" do
    import
    attempt = SkillAttempt.find_by!(external_id: "0x1505877b/1788611732667/1")

    expect(attempt).to have_attributes(
      recorded_at: be_within(0.001).of(Time.at(1788611736.315).utc),
      run_started_at: be_within(0.001).of(Time.at(1788611732.667).utc),
      sequence: 1,
      character_name: "Sif The Dog",
      character_serial: "0x1505877b",
      skill: "bowcraft_fletching",
      skill_from: 32.0,
      skill_to: 32.1,
      outcome: "failed",
      subject: "bow"
    )
    expect(attempt).not_to be_success

    expect(attempt.consumed_materials.sole).to have_attributes(
      name: "regular boards", graphic: "0x1bd7", hue: 0, quantity: 7
    )
  end

  it "files the client's Bowcraft under Bowcraft/Fletching" do
    import
    attempt = SkillAttempt.find_by!(external_id: "0x1505877b/1788610215114/1")

    expect(attempt.skill_before_type_cast).to eq("Bowcraft/Fletching")
    expect(attempt).to be_bowcraft_fletching
    expect(attempt).to be_made
    expect(attempt.consumed_materials.count).to eq(1)
  end

  it "leaves out a row whose skill_to the client never answered" do
    import

    expect(SkillAttempt.find_by(external_id: "0x1505877b/1788689627575/4")).to be_nil
  end

  it "changes nothing when the same file is imported twice" do
    import

    result = nil

    expect { result = import }.not_to change { [ SkillAttempt.count, ConsumedMaterial.count, GatheredMaterial.count ] }
    expect(result.imported).to eq(0)
    expect(result.skipped).to eq(6)
  end

  it "maps a dug mining row with its gathered ore" do
    import
    attempt = SkillAttempt.find_by!(external_id: "0x1505877b/1789056730585/32")

    expect(attempt).to have_attributes(
      skill: "mining", outcome: "dug", skill_from: 79.0, skill_to: 79.1, subject: "pickaxe"
    )
    expect(attempt).to be_success
    expect(attempt.consumed_materials).to be_empty
    expect(attempt.gathered_materials.sole).to have_attributes(
      name: "iron ore", graphic: "0x19b7", hue: 0, quantity: 2
    )
  end

  it "leaves a failed mining swing with no materials at all" do
    import
    attempt = SkillAttempt.find_by!(external_id: "0x1505877b/1789056730585/36")

    expect(attempt).to have_attributes(outcome: "failed", skill_from: 79.2, skill_to: 79.2)
    expect(attempt).not_to be_success
    expect(attempt.consumed_materials).to be_empty
    expect(attempt.gathered_materials).to be_empty
  end

  it "maps a smelting row with both consumed ore and gathered ingots" do
    import
    attempt = SkillAttempt.find_by!(external_id: "0x1505877b/1789056730585/34")

    expect(attempt).to have_attributes(
      skill: "mining", outcome: "smelted", skill_from: 79.1, skill_to: 79.1, subject: "fire beetle"
    )
    expect(attempt).to be_success
    expect(attempt.consumed_materials.sole).to have_attributes(name: "iron ore", quantity: 98)
    expect(attempt.gathered_materials.sole).to have_attributes(name: "98 Ingots", quantity: 49)
  end

  it "refuses a path that does not exist" do
    expect { described_class.call("/nowhere/nothing.jsonl") }.to raise_error(ArgumentError, /no such file/)
  end
end
