# frozen_string_literal: true

RSpec.describe ChangedColumn do
  let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
  let(:public_type_de_champs) do
    [
      { type: :header_section, libelle: "Titre", stable_id: 98 },
      { type: :text, libelle: "Texte", stable_id: 99 },
      { type: :text, libelle: "Autre texte", stable_id: 991 },
      { type: :repetition, libelle: "Répétition", stable_id: 993, children: [{ type: :text, libelle: 'Nom', stable_id: 994 }] },
      { type: :piece_justificative, libelle: "Pièce", stable_id: 997 },
      { type: :piece_justificative, libelle: "Identité", stable_id: 998, nature: 'titre_identite' },
    ]
  end
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:instructeur) { create(:instructeur) }

  describe '.columns' do
    subject(:columns) { dossier.instructeur_changed_columns }

    context 'when a text champ is changed' do
      before do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update('99', updated_by: instructeur.email).assign_attributes(value: "Nouvelle valeur")
          dossier.public_champ_for_update('991', updated_by: instructeur.email)
        end
        dossier.save!
      end

      it 'carries the new and the previous value' do
        expect(columns.map(&:stable_id)).to eq([99])

        column = columns.first
        expect(column.label).to eq("Texte")
        expect(column.value).to eq("Nouvelle valeur")
        expect(column.previous_value).to eq(dossier.champ_data.find { _1.stable_id == 99 && _1.main_stream? }.value)
        expect(column.previous_value).not_to eq("Nouvelle valeur")
      end

      it 'ignores champs copied to the buffer without a change, and non fillable champs' do
        expect(columns.map(&:stable_id)).not_to include(991, 98)
      end
    end

    context 'when a champ is emptied' do
      before do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update('99', updated_by: instructeur.email).assign_attributes(value: '')
        end
        dossier.save!
      end

      it 'reports a nil value' do
        expect(columns.map(&:stable_id)).to eq([99])
        expect(columns.first.value).to be_nil
        expect(columns.first.previous_value).to be_present
      end
    end

    context 'when a repetition row is added' do
      before do
        type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
        dossier.with_instructeur_buffer_stream do
          row_id = dossier.repetition_add_row(type_de_champ, updated_by: instructeur.email)
          dossier.public_champ_for_update("994-#{row_id}", updated_by: instructeur.email).assign_attributes(value: "Nouvelle ligne")
        end
        dossier.save!
      end

      it 'reports the row champs prefixed with the repetition libellé' do
        column = columns.find { _1.value == "Nouvelle ligne" }

        expect(column.stable_id).to eq(994)
        expect(column.label).to eq("Répétition – Nom")
        expect(column.previous_value).to be_nil
      end
    end

    context 'when a titre d’identité is attached' do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      before do
        dossier.with_instructeur_buffer_stream do
          champ = dossier.public_champ_for_update('998', updated_by: instructeur.email)
          champ.piece_justificative_file.attach(io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf')
          champ.save!
        end
        dossier.save!
      end

      it 'reports it under its libellé without exposing the file' do
        column = columns.find { _1.stable_id == 998 }

        expect(column.label).to eq("Identité")
        expect(column.type).to eq(:text)
        expect(column.value).to eq('présent')
        expect(column.previous_value).to eq('absent')
      end
    end

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
