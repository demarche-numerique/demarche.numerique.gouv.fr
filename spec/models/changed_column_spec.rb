# frozen_string_literal: true

RSpec.describe ChangedColumn do
  let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
  let(:public_type_de_champs) do
    [
      { type: :text, libelle: "Texte", stable_id: 99 },
      { type: :piece_justificative, libelle: "Pièce", stable_id: 997 },
    ]
  end
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:instructeur) { create(:instructeur) }

  describe '.columns' do
    subject(:columns) { dossier.instructeur_changed_columns }

    context 'when a piece justificative champ is copied to the buffer without touching its files' do
      before do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update('997', updated_by: instructeur.email)
        end
        dossier.save!
      end

      it 'does not report the cloned attachments as a change' do
        expect(columns).to eq([])
      end
    end

    context 'when a file is replaced by another one with the same name' do
      before do
        dossier.with_instructeur_buffer_stream do
          champ = dossier.public_champ_for_update('997', updated_by: instructeur.email)
          champ.piece_justificative_file.purge
          champ.piece_justificative_file.attach(io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'toto.txt')
          champ.save!
        end
        dossier.save!
      end

      it 'reports the change' do
        expect(columns.map(&:stable_id)).to eq([997])
      end
    end
  end
end
