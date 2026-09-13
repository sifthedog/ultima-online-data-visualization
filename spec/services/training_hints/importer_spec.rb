require "rails_helper"

RSpec.describe TrainingHints::Importer do
  let(:path) { file_fixture("training-hints.json").to_s }

  def import
    described_class.call(path)
  end

  it "imports each known skill's hints in file order and reports the rest" do
    result = nil

    expect { result = import }.to change(TrainingHint, :count).by(3)

    expect(result.imported).to eq(3)
    expect(result.problems).to contain_exactly(
      'unknown skill "Taming"',
      "Magery: expected a list of non-blank strings"
    )
    expect(TrainingHint.mining.order(:id).pluck(:body)).to eq([ "Dig in the Minoc caves until 70", "Switch to a prospector's tool at 90" ])
    expect(TrainingHint.bowcraft_fletching.sole.body).to eq("Make bows until 40")
  end

  it "replaces a listed skill's hints and leaves unlisted skills alone" do
    stale = create(:training_hint, skill: :mining, body: "old")
    untouched = create(:training_hint, skill: :tailoring)

    import

    expect(TrainingHint.exists?(stale.id)).to be(false)
    expect(TrainingHint.mining.count).to eq(2)
    expect(untouched.reload).to be_persisted
  end

  it "changes nothing when the same file is imported twice" do
    import

    expect { import }.not_to change { TrainingHint.order(:id).pluck(:skill, :body) }
  end

  it "refuses a path that does not exist" do
    expect { described_class.call("/nowhere/hints.json") }.to raise_error(ArgumentError, /no such file/)
  end
end
