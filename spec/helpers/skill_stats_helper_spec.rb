require "rails_helper"

RSpec.describe SkillStatsHelper do
  include SkillStatsHelper

  describe "#grouped_by_metal" do
    it "pairs each metal's ore with its ingots, ore first, groups ordered by largest quantity" do
      quantities = { "iron ore" => 10.0, "dull copper ingots" => 50.0, "dull copper ore" => 5.0, "ingots" => 1.0 }

      expect(grouped_by_metal(quantities)).to eq(
        [
          [ "dull copper", [ [ "dull copper ore", 5.0 ], [ "dull copper ingots", 50.0 ] ] ],
          [ "iron", [ [ "iron ore", 10.0 ], [ "ingots", 1.0 ] ] ]
        ]
      )
    end
  end
end
