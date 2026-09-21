# frozen_string_literal: true

describe RepetitionRow do
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

  # the repetition starts with one row
  before { 3.times { dossier.root_champs_public.find(&:repetition?).add_row(updated_by: 'test') } }

  describe '#spreadsheet_columns' do
    it 'exports the dossier id as a string and the 1-based row index' do
      repetition = procedure.active_revision.public_root_type_de_champs.find(&:repetition?)
      row = fresh_dossier.project_rows_for(repetition).second

      expect(row.spreadsheet_columns([], format: :xlsx)).to eq([['Dossier ID', dossier.id.to_s], ['Ligne', :index]])
      expect(row.index).to eq(2)
    end
  end
end
