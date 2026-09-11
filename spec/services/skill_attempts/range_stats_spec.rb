require "rails_helper"

RSpec.describe SkillAttempts::RangeStats do
  def attempt(from, gained: true, subject: "bow", serial: "0xabc", boards: 7, ore: nil, outcome: nil, skill: :bowcraft_fletching)
    attempt = create(
      :skill_attempt,
      skill:, subject:, character_serial: serial,
      skill_from: from, skill_to: gained ? from + 0.1 : from,
      outcome: outcome || (gained ? :made : :failed)
    )
    create(:consumed_material, skill_attempt: attempt, quantity: boards) if boards
    create(:gathered_material, skill_attempt: attempt, quantity: ore) if ore
    attempt
  end

  def stats(from_tenths: 600, to_tenths: 610, skill: :bowcraft_fletching, subject: nil)
    described_class.call(skill:, from_tenths:, to_tenths:, subject:)
  end

  it "pools two characters passing through the same step instead of adding their attempts" do
    3.times { attempt(60.0, gained: false, serial: "0xaaa") }
    attempt(60.0, serial: "0xaaa")
    attempt(60.0, serial: "0xbbb")

    summary = stats(to_tenths: 601).summary

    expect(summary.attempts).to eq(5)
    expect(summary.expected_attempts).to eq(2.5)
    expect(summary.covered_steps).to eq(1)
  end

  it "reports steps without a gain as gaps and keeps their attempts out of the estimate" do
    attempt(60.0)
    attempt(60.1, gained: false)
    attempt(60.2)

    summary = stats(to_tenths: 603).summary

    expect(summary.total_steps).to eq(3)
    expect(summary.covered_steps).to eq(2)
    expect(summary.coverage_ratio).to be_within(0.001).of(2 / 3.0)
    expect(summary.uncovered_ranges).to eq([ [ 601, 602 ] ])
    expect(summary.attempts).to eq(3)
    expect(summary.uncovered_attempts).to eq(1)
    expect(summary.expected_attempts).to eq(2.0)
  end

  it "lists leading and trailing gaps over the whole default range" do
    attempt(60.0)

    summary = stats(from_tenths: 0, to_tenths: 1200).summary

    expect(summary.uncovered_ranges).to eq([ [ 0, 600 ], [ 601, 1200 ] ])
    expect(summary.total_steps).to eq(1200)
  end

  it "normalizes materials per gain and averages them per skill point" do
    2.times { attempt(60.0, gained: false) }
    2.times { attempt(60.0) }
    attempt(60.1)

    summary = stats(to_tenths: 602).summary

    expect(summary.consumption).to eq("regular boards" => 21.0)
    expect(summary.average_consumption["regular boards"]).to be_within(0.001).of(105.0)
  end

  it "narrows to one subject and skips the breakdown when a subject is given" do
    attempt(60.0, subject: "bow")
    attempt(60.0, gained: false, subject: "crossbow")
    attempt(60.0, subject: "crossbow")

    result = stats(to_tenths: 601, subject: "crossbow")

    expect(result.summary.attempts).to eq(2)
    expect(result.summary.expected_attempts).to eq(2.0)
    expect(result.by_subject).to be_empty
  end

  it "pools every subject for the headline and summarizes each one separately" do
    attempt(60.0, subject: "bow")
    attempt(60.0, gained: false, subject: "crossbow")
    attempt(60.0, subject: "crossbow")

    result = stats(to_tenths: 601)

    expect(result.summary.expected_attempts).to eq(1.5)
    expect(result.by_subject.keys).to eq(%w[crossbow bow])
    expect(result.by_subject["crossbow"].success_rate).to eq(0.5)
    expect(result.by_subject["bow"].success_rate).to eq(1.0)
  end

  it "pools every subject's attempts at a step into the same gain" do
    5.times { attempt(62.9, gained: false, subject: "Stone Form", boards: nil, outcome: :cast) }
    attempt(62.9, subject: "Cleansing Winds", boards: nil, outcome: :cast)

    summary = stats(from_tenths: 629, to_tenths: 630).summary

    expect(summary.attempts).to eq(6)
    expect(summary.expected_attempts).to eq(6.0)
    expect(summary.uncovered_attempts).to eq(0)
  end

  it "includes the from step and excludes the to step" do
    attempt(60.0)
    attempt(61.0)
    attempt(59.9)

    summary = stats.summary

    expect(summary.attempts).to eq(1)
    expect(summary.covered_steps).to eq(1)
  end

  it "counts a gain regardless of outcome" do
    attempt(60.0, gained: true, outcome: :failed)
    attempt(60.1, gained: false, outcome: :made)

    summary = stats(to_tenths: 602).summary

    expect(summary.covered_steps).to eq(1)
    expect(summary.attempts).to eq(2)
    expect(summary.success_rate).to eq(0.5)
  end

  it "buckets steps into skill points and scales partially covered ones" do
    7.times { |index| attempt(60.0 + index / 10.0) }
    attempt(61.0, gained: false)

    points = stats(to_tenths: 620).summary.points

    expect(points.size).to eq(2)
    expect(points[0]).to have_attributes(point: 60, steps_in_range: 10, covered_steps: 7, expected: 7.0, partial: true)
    expect(points[0].scaled).to be_within(0.001).of(10.0)
    expect(points[1]).to have_attributes(point: 61, covered_steps: 0, scaled: nil, partial: false)
  end

  it "refuses to scale up a point covered by fewer than half its steps" do
    4.times { |index| attempt(60.0 + index / 10.0) }

    points = stats(to_tenths: 610).summary.points

    expect(points[0]).to have_attributes(point: 60, covered_steps: 4, expected: 4.0, scaled: nil, partial: true)
  end

  it "respects range edges that fall inside a skill point" do
    attempt(60.5)

    points = stats(from_tenths: 605, to_tenths: 611).summary.points

    expect(points.map(&:steps_in_range)).to eq([ 5, 1 ])
  end

  it "is empty with the whole range uncovered when the skill has no data" do
    summary = stats(skill: :magery, from_tenths: 0, to_tenths: 1200).summary

    expect(summary).to be_empty
    expect(summary.covered_steps).to eq(0)
    expect(summary.expected_attempts).to eq(0.0)
    expect(summary.attempts_per_point).to be_nil
    expect(summary.uncovered_ranges).to eq([ [ 0, 1200 ] ])
  end

  it "has no consumption for spells" do
    attempt(60.0, skill: :mysticism, subject: "Stone Form", outcome: :cast, boards: nil)

    summary = stats(skill: :mysticism, to_tenths: 601).summary

    expect(summary.expected_attempts).to eq(1.0)
    expect(summary.consumption).to eq({})
    expect(summary.average_consumption).to eq({})
  end

  it "has no gathered materials for skills that never mine" do
    attempt(60.0, skill: :mysticism, subject: "Stone Form", outcome: :cast, boards: nil)

    summary = stats(skill: :mysticism, to_tenths: 601).summary

    expect(summary.gathered).to eq({})
    expect(summary.average_yield).to eq({})
  end

  it "normalizes gathered materials per swing, independent of skill gain" do
    4.times { attempt(79.0, gained: false, skill: :mining, subject: "pickaxe", boards: nil, outcome: :dug, ore: 2) }

    summary = stats(skill: :mining, from_tenths: 790, to_tenths: 791).summary

    expect(summary.covered_steps).to eq(0)
    expect(summary.consumption).to eq({})
    expect(summary.yield_covered_steps).to eq(1)
    expect(summary.gathered).to eq("iron ore" => 2.0)
    expect(summary.average_yield["iron ore"]).to eq(2.0)
  end

  it "pools smelting consumption and mining gathering under the same skill without mixing subjects in the by-subject breakdown" do
    attempt(79.0, gained: true, skill: :mining, subject: "pickaxe", boards: nil, outcome: :dug, ore: 2)
    smelt = attempt(79.0, gained: false, skill: :mining, subject: "fire beetle", boards: nil, outcome: :smelted, ore: nil)
    create(:consumed_material, skill_attempt: smelt, name: "iron ore", quantity: 98)
    create(:gathered_material, skill_attempt: smelt, name: "98 Ingots", quantity: 49)

    result = stats(skill: :mining, from_tenths: 790, to_tenths: 791)

    expect(result.summary.consumption).to eq("iron ore" => 98.0)
    expect(result.summary.gathered).to eq("iron ore" => 1.0, "98 Ingots" => 24.5)

    expect(result.by_subject["pickaxe"].consumption).to eq({})
    expect(result.by_subject["pickaxe"].gathered).to eq("iron ore" => 2.0)
    # Smelting never raises skill on its own, so its own gain-based coverage is empty: the
    # smelted ore only shows up in the pooled summary above thanks to the pickaxe swing's gain.
    expect(result.by_subject["fire beetle"].consumption).to eq({})
    expect(result.by_subject["fire beetle"].gathered).to eq("98 Ingots" => 49.0)
  end

  it "credits every step a single row climbed through" do
    create(:skill_attempt, subject: "bow", skill_from: 60.0, skill_to: 60.2, outcome: :made)

    summary = stats(to_tenths: 602).summary

    expect(summary.attempts).to eq(1)
    expect(summary.covered_steps).to eq(2)
    expect(summary.uncovered_ranges).to be_empty
    expect(summary.expected_attempts).to eq(1.0)
  end

  it "credits a step inside the range to a row that started just below it" do
    create(:skill_attempt, subject: "bow", skill_from: 59.9, skill_to: 60.1, outcome: :made)

    summary = stats(to_tenths: 601).summary

    expect(summary.attempts).to eq(0)
    expect(summary.covered_steps).to eq(1)
  end

  it "counts a row whose end the client never answered as an attempt with no gain" do
    create(:skill_attempt, subject: "bow", skill_from: 60.0, skill_to: nil, outcome: :failed)

    summary = stats(to_tenths: 601).summary

    expect(summary.attempts).to eq(1)
    expect(summary.covered_steps).to eq(0)
    expect(summary.uncovered_attempts).to eq(1)
  end
end
