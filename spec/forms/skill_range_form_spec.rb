require "rails_helper"

RSpec.describe SkillRangeForm do
  it "defaults to the whole 0 to 120 range" do
    form = described_class.new(skill: "mysticism")

    expect(form).to be_valid
    expect(form.from_tenths).to eq(0)
    expect(form.to_tenths).to eq(1200)
  end

  it "is not filled until a skill is chosen" do
    expect(described_class.new).not_to be_filled
    expect(described_class.new(skill: "mysticism")).to be_filled
  end

  it "rejects a skill the shard does not track" do
    form = described_class.new(skill: "taming")

    expect(form).not_to be_valid
    expect(form.errors[:skill]).to include("is not a known skill")
  end

  it "requires from to be below to" do
    form = described_class.new(skill: "mysticism", from: "80", to: "50")

    expect(form).not_to be_valid
    expect(form.errors[:to]).to include("must be greater than from")
  end

  it "keeps the range inside 0 and 120" do
    expect(described_class.new(skill: "mysticism", from: "-1")).not_to be_valid
    expect(described_class.new(skill: "mysticism", to: "120.1")).not_to be_valid
  end

  it "only accepts tenths" do
    form = described_class.new(skill: "mysticism", from: "50.05")

    expect(form).not_to be_valid
    expect(form.errors[:from]).to include("must be a multiple of 0.1")
  end

  it "converts decimal strings to tenths without drift" do
    form = described_class.new(skill: "mysticism", from: "50.3", to: "99.9")

    expect(form.from_tenths).to eq(503)
    expect(form.to_tenths).to eq(999)
  end

  it "offers only the chosen skill's subjects and drops a stale one" do
    create(:skill_attempt, :mysticism, subject: "Stone Form")
    create(:skill_attempt, subject: "bow")

    form = described_class.new(skill: "mysticism", subject: "bow")

    expect(form.subject_options).to eq([ "Stone Form" ])
    expect(form.chosen_subject).to be_nil
    expect(form.to_query).to eq(skill: "mysticism", from_tenths: 0, to_tenths: 1200, subject: nil)
  end
end
