require "rails_helper"

RSpec.describe "Skill stats chart", type: :system do
  # Half of each point's steps recorded a gain, the minimum coverage that still gets an estimate,
  # so every bar is scaled 10/5 = 2× and each point comes to 5 attempts × 2 = 10.
  before do
    [ 31, 32 ].each do |point|
      (0..4).each do |step|
        create(:skill_attempt, skill_from: point + step / 10.0, skill_to: point + (step + 1) / 10.0)
      end
    end
  end

  it "summarizes the span a drag across bars covers" do
    visit root_path(skill: "bowcraft_fletching", from: "31", to: "33")

    bars = all("[data-chart-target='band']")
    bars.first.drag_to(bars.last)

    expect(find("[data-testid='chart-tooltip']").text).to eq("31.0–33.0\n20.0 attempts\n10.0 per point\n2 points")
  end
end
