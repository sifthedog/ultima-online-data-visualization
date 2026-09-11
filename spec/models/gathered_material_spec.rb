require "rails_helper"

RSpec.describe GatheredMaterial do
  it_behaves_like "a skill attempt material",
    factory: :gathered_material, association: :gathered_materials, material_name: "iron ore", attempt_traits: [ :mining ]
end
