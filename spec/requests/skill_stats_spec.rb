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
    expect(response.body).to include("Total regular boards")
    expect(response.body).to include("<svg")
    expect(response.body).to include('data-testid="subjects"')
    expect(response.body).to include("crossbow")
  end

  it "shows gathered-material tiles for mining alongside any consumption" do
    dug = create(:skill_attempt, :mining)
    create(:gathered_material, skill_attempt: dug, quantity: 2)
    smelted = create(:skill_attempt, :smelted)
    create(:consumed_material, skill_attempt: smelted, quantity: 98)
    create(:gathered_material, skill_attempt: smelted, name: "98 Ingots", quantity: 49)

    get root_path(skill: "mining", from: "79", to: "80")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Total iron ore")
    expect(response.body).to include("Iron ore per swing")
    expect(response.body).to include("Total 98 Ingots")
  end

  it "hides the subject table when a subject is chosen" do
    create(:skill_attempt, subject: "bow")

    get root_path(skill: "bowcraft_fletching", from: "31", to: "32", subject: "bow")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Expected attempts")
    expect(response.body).not_to include('data-testid="subjects"')
  end

  it "says so when the skill has no data in the range" do
    get root_path(skill: "magery")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No attempts recorded for this skill in this range.")
    expect(response.body).not_to include("<svg")
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
