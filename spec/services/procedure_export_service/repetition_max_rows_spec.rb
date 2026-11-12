# frozen_string_literal: true

describe ProcedureExportService::RepetitionMaxRows do
  let_it_be(:procedure) do
    create(:procedure, public_type_de_champs: [
      { type: :repetition, stable_id: 10, libelle: 'Enfants', children: [{ type: :text, stable_id: 11 }] },
      { type: :repetition, stable_id: 20, libelle: 'Véhicules', children: [{ type: :text, stable_id: 21 }] },
    ])
  end

  let(:dossier_a) { create(:dossier, procedure:) }
  let(:dossier_b) { create(:dossier, procedure:) }
  let(:dossiers) { Dossier.where(id: [dossier_a, dossier_b]) }

  def add_rows(dossier, stable_id, count)
    type_de_champ = dossier.find_type_de_champ_by_stable_id(stable_id)
    Array.new(count) { dossier.repetition_add_row(type_de_champ, updated_by: 'test') }
  end

  subject(:max_rows) { described_class.new(dossiers:, stable_ids: [10, 20]).to_h }

  it 'counts the row a new dossier starts with' do
    expect(max_rows).to eq(10 => 1, 20 => 1)
  end

  it 'returns the highest row count of each repetition' do
    add_rows(dossier_a, 10, 1)
    add_rows(dossier_b, 10, 3)
    add_rows(dossier_a, 20, 1)

    expect(max_rows).to eq(10 => 4, 20 => 2)
  end

  it 'merges the maximum across batches of dossiers' do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    add_rows(dossier_a, 10, 3)
    add_rows(dossier_b, 20, 2)
    service = described_class.new(dossiers:, stable_ids: [10, 20])

    expect(service).to receive(:max_rows_for).twice.and_call_original
    expect(service.to_h).to eq(10 => 4, 20 => 3)
  end

  it 'ignores discarded rows' do
    row_ids = add_rows(dossier_a, 10, 2)
    type_de_champ = dossier_a.find_type_de_champ_by_stable_id(10)
    dossier_a.repetition_remove_row(type_de_champ, row_ids.first, updated_by: 'test')

    expect(max_rows[10]).to eq(2)
  end

  it 'ignores dossiers outside the export' do
    other_dossier = create(:dossier, procedure:)
    add_rows(other_dossier, 10, 4)

    expect(max_rows[10]).to eq(1)
  end

  it 'ignores rows on a buffer stream' do
    dossier_a.with_instructeur_buffer_stream { add_rows(dossier_a, 10, 2) }

    expect(max_rows[10]).to eq(1)
  end

  it 'ignores repetitions that were not asked for' do
    add_rows(dossier_a, 20, 2)

    expect(described_class.new(dossiers:, stable_ids: [10]).to_h).to eq(10 => 1)
  end

  it 'counts the rows the export reads' do
    add_rows(dossier_a, 10, 2)
    type_de_champ = dossier_b.find_type_de_champ_by_stable_id(10)
    dossier_b.repetition_remove_row(type_de_champ, add_rows(dossier_b, 10, 1).first, updated_by: 'test')
    dossier_a.with_instructeur_buffer_stream { add_rows(dossier_a, 10, 2) }

    projected = dossiers.map do |dossier|
      dossier = Dossier.find(dossier.id)
      ProcedureExportService::RepetitionRow.for(dossier, dossier.find_type_de_champ_by_stable_id(10)).size
    end

    expect(max_rows[10]).to eq(projected.max)
  end

  it 'runs no query without repetition' do
    service = described_class.new(dossiers:, stable_ids: [])
    queries = []
    callback = -> (*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      expect(service.to_h).to eq({})
    end

    expect(queries).to be_empty
  end
end
