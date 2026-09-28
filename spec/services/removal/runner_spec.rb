# frozen_string_literal: true

describe Removal::Runner do
  let(:brouillon) { dossiers.brouillon }
  let(:en_construction) { dossiers.en_construction }
  let(:accepte) { dossiers.accepte }
  let(:three_dossiers) { Dossier.where(id: [brouillon, en_construction, accepte]).order(:id) }

  def batches(runner, *selection)
    [].tap { |batches| runner.each_batch(*selection) { batches << it.ids.sort } }
  end

  it "keeps the dossiers of one user in one batch, growing it past the batch size" do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    en_construction.update_column(:user_id, users.instructeur.id)

    expect(batches(described_class.new(scope: three_dossiers)))
      .to eq([[brouillon.id, accepte.id].sort, [en_construction.id]])
  end

  it "checks the scope again when processing a batch of a narrower selection" do
    runner = described_class.new(scope: Dossier.state_brouillon)

    expect(batches(runner, three_dossiers)).to eq([[brouillon.id]])
  end

  it "yields nothing for an empty scope" do
    expect(batches(described_class.new(scope: Dossier.none))).to eq([])
  end
end
