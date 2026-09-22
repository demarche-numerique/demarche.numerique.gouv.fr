# frozen_string_literal: true

describe Removal::Runner do
  let(:brouillon) { dossiers.brouillon }
  let(:en_construction) { dossiers.en_construction }
  let(:accepte) { dossiers.accepte }

  def batches(runner, ids_and_user_ids)
    [].tap { |batches| runner.each_batch(ids_and_user_ids) { batches << it.ids.sort } }
  end

  it "keeps the dossiers of one user in one batch, growing it past the batch size" do
    runner = described_class.new(scope: Dossier.all, batch_size: 1)
    ids_and_user_ids = [[brouillon.id, 1], [en_construction.id, 2], [accepte.id, 1]]

    expect(batches(runner, ids_and_user_ids)).to eq([[brouillon.id, accepte.id].sort, [en_construction.id]])
  end

  it "checks the scope again when processing a batch" do
    runner = described_class.new(scope: Dossier.state_brouillon)

    expect(batches(runner, [[brouillon.id, 1], [en_construction.id, 2]])).to eq([[brouillon.id]])
  end

  it "yields nothing for an empty selection" do
    expect(batches(described_class.new(scope: Dossier.all), [])).to eq([])
  end
end
