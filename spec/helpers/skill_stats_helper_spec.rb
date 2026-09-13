require "rails_helper"

RSpec.describe SkillStatsHelper do
  include SkillStatsHelper

  describe "#grouped_by_resource" do
    it "pairs each metal's ore with its ingots, ore first, groups ordered by largest quantity" do
      quantities = { "iron ore" => 10.0, "dull copper ingots" => 50.0, "dull copper ore" => 5.0, "ingots" => 1.0 }

      expect(grouped_by_resource(quantities)).to eq(
        [
          [ "dull copper", [ [ "dull copper ore", 5.0 ], [ "dull copper ingots", 50.0 ] ] ],
          [ "iron", [ [ "iron ore", 10.0 ], [ "ingots", 1.0 ] ] ]
        ]
      )
    end

    it "pairs each wood's logs with its boards, logs first" do
      quantities = { "boards" => 3.0, "oak boards" => 40.0, "logs" => 20.0, "oak logs" => 4.0 }

      expect(grouped_by_resource(quantities)).to eq(
        [
          [ "oak", [ [ "oak logs", 4.0 ], [ "oak boards", 40.0 ] ] ],
          [ "", [ [ "logs", 20.0 ], [ "boards", 3.0 ] ] ]
        ]
      )
    end
  end
end
