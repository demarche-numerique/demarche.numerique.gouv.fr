# frozen_string_literal: true

describe ProcedureExportService::InlineRepetitionsBuilder do
  describe '#to_h' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Enfants', stable_id: 7 }])
    end
    let(:export_template) do
      create(:export_template, kind: 'csv', groupe_instructeur: procedure.defaut_groupe_instructeur,
        exported_columns: [ExportedColumn.new(libelle: 'Enfants – Prénom', column: procedure.find_column(label: 'Enfants – Prénom'))])
    end

    subject { described_class.new(procedure:, dossiers: procedure.dossiers, export_template:).to_h }

    context 'when the repetition was another type of champ in a previous revision' do
      before do
        draft = procedure.draft_revision
        repetition = draft.find_and_ensure_exclusive_use(7).becomes_type('repetition')
        draft.update_type_de_champ(repetition, type_champ: 'repetition', limit_repetitions: true, max_repetitions: 3)
        draft.add_type_de_champ(type_champ: 'text', libelle: 'Prénom', parent_stable_id: 7)
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it 'uses the maximum of the repetition' do
        expect(subject[7].max_rows).to eq(3)
      end
    end
  end
end
