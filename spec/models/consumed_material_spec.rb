require "rails_helper"

RSpec.describe ConsumedMaterial do
  it_behaves_like "a skill attempt material",
    factory: :consumed_material, association: :consumed_materials, material_name: "regular boards"
end
