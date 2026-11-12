# frozen_string_literal: true

describe ProcedureExportService::RepetitionRow do
  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      {
        type: :repetition,
        libelle: 'Bloc',
        children: [{ type: :text, libelle: 'Nom' }, { type: :text, libelle: 'Prénom' }],
      },
    ])
  end
  let(:dossier) { create(:dossier, procedure:) }
  let(:fresh_dossier) { Dossier.find(dossier.id) }
  let(:repetition) { procedure.active_revision.public_root_type_de_champs.find(&:repetition?) }

  # the repetition starts with one row
  before { 3.times { dossier.public_root_champs.find(&:repetition?).add_row(updated_by: 'test') } }

  describe '.for' do
    it 'numbers the rows of the dossier from 1, in row id order' do
      rows = described_class.for(fresh_dossier, repetition)

      expect(rows.map(&:id)).to eq(fresh_dossier.repetition_row_ids(repetition))
      expect(rows.map(&:index)).to eq([1, 2, 3, 4])
    end
  end

  describe '#spreadsheet_columns' do
    it 'exports the dossier id as a string and the 1-based row index' do
      row = described_class.for(fresh_dossier, repetition).second

      expect(row.spreadsheet_columns([], format: :xlsx)).to eq([['Dossier ID', dossier.id.to_s], ['Ligne', :index]])
      expect(row.index).to eq(2)
    end
  end
end
