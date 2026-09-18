require "rails_helper"

RSpec.describe "Skill stats", type: :request do
  it "asks for a skill before showing anything" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Choose a skill to see")
    expect(response.body).not_to include("<svg")
  end

  it "shows the stats, chart and subject table for a skill and range" do
    attempt = create(:skill_attempt, skill_from: 31.1, skill_to: 31.2, subject: "bow")
    create(:consumed_material, skill_attempt: attempt, quantity: 7)
    create(:skill_attempt, skill_from: 31.2, skill_to: 31.2, outcome: :failed, subject: "crossbow")

    get root_path(skill: "bowcraft_fletching", from: "31", to: "32")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("1 of 10")
    expect(response.body).to include("31.0–31.1")
    expect(response.body).to include("31.2–32.0")
    expect(response.body).to include("Total Regular Boards")
    expect(response.body).to include("<svg")
    expect(response.body).to include('data-testid="subjects"')
    expect(response.body).to include("Crossbow")
    expect(response.body).to include('data-testid="tiers"')
    expect(response.body).to include("Bow")
  end

  it "shows a per-resource materials table for mining instead of the tile grid or tool-grouped tables" do
    dug = create(:skill_attempt, :mining)
    create(:gathered_material, skill_attempt: dug, name: "iron ore", quantity: 2)
    create(:skill_attempt, :mining, skill_from: 79.1, skill_to: 79.2)
    smelted = create(:skill_attempt, :smelted)
    create(:consumed_material, skill_attempt: smelted, name: "iron ore", quantity: 98)
    create(:gathered_material, skill_attempt: smelted, name: "ingots", quantity: 49)
    create(:gathered_material, skill_attempt: smelted, name: "dull copper ingots", hue: 2419, quantity: 12)

    get root_path(skill: "mining", from: "79", to: "80")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<svg")
    expect(response.body).to include('data-testid="gathered-materials"')
    expect(response.body).to include("Iron Ore")
    expect(response.body).to include("Dull Copper Ingots")
    expect(response.body).to include('data-testid="gathered-per-point"')
    expect(response.body).not_to include("Total Iron Ore")
    expect(response.body).not_to include('data-testid="subjects"')
    expect(response.body).not_to include('data-testid="tiers"')
  end

  it "shows the same per-resource tables for lumberjacking" do
    chopped = create(:skill_attempt, :lumberjacking)
    create(:gathered_material, skill_attempt: chopped, name: "logs", graphic: "0x1bdd", quantity: 20)
    create(:skill_attempt, :lumberjacking, skill_from: 10.7, skill_to: 10.8)
    converted = create(:skill_attempt, :converted)
    create(:consumed_material, skill_attempt: converted, name: "oak logs", hue: 2010, quantity: 50)
    create(:gathered_material, skill_attempt: chopped, name: "oak logs", hue: 2010, quantity: 4)

    get root_path(skill: "lumberjacking", from: "10", to: "11")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-testid="gathered-materials"')
    expect(response.body).to include("Logs")
    expect(response.body).to include("Oak Logs")
    expect(response.body).to include('data-testid="gathered-per-point"')
    # Boards name the conversion in the subject filter, but no table counts them as wood gathered.
    expect(response.body.scan(/data-testid="gathered-[a-z-]+".*?<\/section>/m).join).not_to include("Boards")
    expect(response.body).not_to include("Total Logs")
    expect(response.body).not_to include('data-testid="subjects"')
    expect(response.body).not_to include('data-testid="tiers"')
  end

  it "shows a hiding run without the one-subject table or the empty material columns" do
    create(:skill_attempt, :hiding)
    create(:skill_attempt, :hiding, skill_from: 42.5, skill_to: 42.5, outcome: :failed)

    get root_path(skill: "hiding", from: "42", to: "43")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<svg")
    expect(response.body).to include("No materials recorded.")
    expect(response.body).to include(%(data-testid="tiers"))
    expect(response.body).not_to include(%(data-testid="subjects"))
    expect(response.body).not_to include("Materials/point")
    expect(response.body).not_to include("<span>Item</span>")
  end

  it "narrows to the chosen gain path" do
    create(:skill_attempt, subject: "bow", gain_path: :legacy)

    get root_path(skill: "bowcraft_fletching", from: "31", to: "32", gain_path: "modern")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No attempts recorded")

    get root_path(skill: "bowcraft_fletching", from: "31", to: "32", gain_path: "legacy")

    expect(response.body).to include("Expected attempts")
    expect(response.body).to include("· Legacy")
  end

  it "shows spellweaving by spell, with no materials to report" do
    create(:skill_attempt, :spellweaving)
    create(:skill_attempt, :spellweaving, skill_from: 45.1, skill_to: 45.2, subject: "Wildfire")

    get root_path(skill: "spellweaving", from: "45", to: "46")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Spellweaving")
    expect(response.body).to include("Arcane Circle")
    expect(response.body).to include("Wildfire")
    expect(response.body).to include("No materials recorded.")
    expect(response.body).not_to include('data-testid="gathered-materials"')
  end

  it "says so when the skill has no data in the range" do
    get root_path(skill: "magery")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No attempts recorded for this skill in this range.")
    expect(response.body).not_to include("<svg")
  end

  it "lists a skill's training hints in order, and nothing when it has none" do
    create(:training_hint, skill: :magery, body: "Cast Magic Arrow")
    create(:training_hint, skill: :magery, body: "Then Fireball")
    create(:training_hint, skill: :mining)

    get root_path(skill: "magery")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-testid="training-hints"')
    expect(response.body.index("Cast Magic Arrow")).to be < response.body.index("Then Fireball")

    get root_path(skill: "tinkering")

    expect(response.body).not_to include('data-testid="training-hints"')
  end

  it "shows validation errors instead of stats" do
    get root_path(skill: "mysticism", from: "80", to: "50")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("To must be greater than from")
    expect(response.body).not_to include('data-testid="headline"')
  end

  it "rejects an unknown skill" do
    get root_path(skill: "nope")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Skill is not a known skill")
  end
end
