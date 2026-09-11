require "rails_helper"

RSpec.describe SkillAttempts::ChainGains do
  def run_at = Time.utc(2026, 9, 5, 9, 59)

  def row(sequence, from, to, run: run_at, serial: "0xabc")
    create(
      :skill_attempt,
      sequence:, skill_from: from, skill_to: to, run_started_at: run, character_serial: serial,
      external_id: "#{serial}/#{run.to_i}/#{sequence}"
    )
  end

  it "raises a row's end to where the next row of the run started" do
    first = row(1, 80.6, 80.6)
    row(2, 80.7, 80.7)

    expect(described_class.call).to eq(1)
    expect(first.reload.skill_to).to eq(80.7)
  end

  it "fills in an end the client never answered" do
    first = row(1, 80.1, nil)
    row(2, 80.1, 80.1)

    expect(described_class.call).to eq(1)
    expect(first.reload.skill_to).to eq(80.1)
  end

  it "leaves a row alone when its end already matches the next start" do
    row(1, 80.6, 80.7)
    row(2, 80.7, 80.7)

    expect(described_class.call).to eq(0)
  end

  it "never lowers an end" do
    first = row(1, 80.6, 80.7)
    row(2, 80.5, 80.5)

    expect(described_class.call).to eq(0)
    expect(first.reload.skill_to).to eq(80.7)
  end

  it "does not chain across runs or over a missing sequence" do
    last_of_run = row(3, 80.6, 80.6)
    row(1, 80.9, 80.9, run: run_at + 1.hour)
    skipped = row(5, 81.0, 81.0, run: run_at + 1.hour)
    row(7, 81.2, 81.2, run: run_at + 1.hour)

    expect(described_class.call).to eq(0)
    expect(last_of_run.reload.skill_to).to eq(80.6)
    expect(skipped.reload.skill_to).to eq(81.0)
  end

  it "changes nothing the second time" do
    row(1, 80.6, 80.6)
    row(2, 80.7, 80.7)
    described_class.call

    expect(described_class.call).to eq(0)
  end
end
