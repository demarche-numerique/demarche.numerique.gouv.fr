# frozen_string_literal: true

RSpec.describe Traitement do
  let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
  let(:public_type_de_champs) do
    [
      { type: :text, libelle: "Texte", stable_id: 99 },
      { type: :text, libelle: "Autre texte", stable_id: 991 },
      { type: :repetition, libelle: "Répétition", stable_id: 993, children: [{ type: :text, libelle: 'Nom', stable_id: 994 }] },
    ]
  end
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

  def repetition_row_id
    type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
    dossier.project_champ(type_de_champ).row_ids.first
  end

  def submit_usager_correction(&block)
    dossier.with_update_stream(dossier.user, &block)
    dossier.save!
    dossier.usager_submit_en_construction!
    dossier.reload
    dossier.traitements.last
  end

  def submit_instructeur_correction(instructeur, &block)
    dossier.with_instructeur_buffer_stream(&block)
    dossier.save!
    dossier.instructeur_submit_en_construction!(instructeur:)
    dossier.reload
    dossier.traitements.last
  end

  describe "#has_changes?" do
    it "is false for the initial depose traitement" do
      expect(dossier.traitements.last.has_changes?).to be(false)
    end

    it "is true for a correction traitement" do
      traitement = submit_usager_correction do
        dossier.public_champ_for_update('99', updated_by: dossier.user.email)
          .assign_attributes(value: "Nouvelle valeur")
      end

      expect(traitement.has_changes?).to be(true)
    end
  end

  describe "#changed_columns" do
    context "when the traitement is the initial depose" do
      subject(:traitement) { dossier.traitements.last }

      it "returns an empty array" do
        expect(traitement.event).to eq(:depose)
        expect(traitement.changed_columns).to eq([])
      end
    end

    context "when the traitement is a usager correction" do
      subject(:traitement) do
        submit_usager_correction do
          dossier.public_champ_for_update('99', updated_by: dossier.user.email)
            .assign_attributes(value: "Nouvelle valeur")
        end
      end

      it "returns the changed column for the modified champ" do
        expect(traitement.event).to eq(:depose_correction_usager)

        columns = traitement.changed_columns
        expect(columns.map(&:stable_id)).to contain_exactly(99)

        column = columns.first
        expect(column.label).to eq("Texte")
        expect(column.value).to eq("Nouvelle valeur")
      end
    end

    context "when the usager correction changes a champ inside a repetition" do
      subject(:traitement) do
        row_id = repetition_row_id
        submit_usager_correction do
          dossier.public_champ_for_update("994-#{row_id}", updated_by: dossier.user.email)
            .assign_attributes(value: "Valeur dans la répétition")
        end
      end

      it "returns the changed column for the repetition child" do
        columns = traitement.changed_columns
        expect(columns.map(&:stable_id)).to include(994)

        column = columns.find { _1.stable_id == 994 }
        expect(column.value).to eq("Valeur dans la répétition")
      end
    end

    context "when the usager correction removes a repetition row" do
      subject(:traitement) do
        type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
        row_id = repetition_row_id
        submit_usager_correction do
          dossier.repetition_remove_row(type_de_champ, row_id, updated_by: dossier.user.email)
        end
      end

      it "reports the removed row champs with their previous value" do
        column = traitement.changed_columns.find { _1.stable_id == 994 }

        expect(column).not_to be_nil
        expect(column.value).to be_nil
        expect(column.previous_value).to be_present
      end
    end

    context "when the same champ is corrected twice" do
      let!(:first_traitement) do
        submit_usager_correction do
          dossier.public_champ_for_update('99', updated_by: dossier.user.email)
            .assign_attributes(value: "Première correction")
        end
      end

      let!(:second_traitement) do
        # the history stream is named after the merge time, at second resolution
        travel 1.minute
        submit_usager_correction do
          dossier.public_champ_for_update('99', updated_by: dossier.user.email)
            .assign_attributes(value: "Seconde correction")
        end
      end

      it "keeps the changes of each traitement" do
        first_column = first_traitement.reload.changed_columns.find { _1.stable_id == 99 }
        second_column = second_traitement.changed_columns.find { _1.stable_id == 99 }

        expect(first_column.value).to eq("Première correction")
        expect(second_column.previous_value).to eq("Première correction")
        expect(second_column.value).to eq("Seconde correction")
      end
    end

    context "when the traitement is an instructeur correction" do
      let(:instructeur) { create(:instructeur) }

      subject(:traitement) do
        submit_instructeur_correction(instructeur) do
          dossier.public_champ_for_update('99', updated_by: instructeur.email)
            .assign_attributes(value: "Correction instructeur")
        end
      end

      it "returns the changed column for the modified champ" do
        expect(traitement.event).to eq(:depose_correction_instructeur)

        columns = traitement.changed_columns
        expect(columns.map(&:stable_id)).to contain_exactly(99)
        expect(columns.first.value).to eq("Correction instructeur")
      end

      # The notification commentaire is built from the in-memory dossier, right
      # after the merge and without a reload. The merge must therefore update the
      # in-memory champ checkpoint, otherwise #changed_columns comes up empty.
      it "returns the changed column without reloading the dossier" do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update('99', updated_by: instructeur.email)
            .assign_attributes(value: "Correction sans reload")
        end
        dossier.save!
        dossier.instructeur_submit_en_construction!(instructeur:)

        columns = dossier.traitements.last.changed_columns
        expect(columns.map(&:stable_id)).to contain_exactly(99)
        expect(columns.first.value).to eq("Correction sans reload")
      end

      # Unlike the usager submit, the instructeur submit does not purge the
      # discarded row champ: it stays on main with the checkpoint.
      it "reports a row edited then removed as removed" do
        type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
        row_id = repetition_row_id
        traitement = submit_instructeur_correction(instructeur) do
          dossier.public_champ_for_update("994-#{row_id}", updated_by: instructeur.email)
            .assign_attributes(value: "Modifié puis supprimé")
          dossier.repetition_remove_row(type_de_champ, row_id, updated_by: instructeur.email)
        end

        column = traitement.changed_columns.find { _1.stable_id == 994 }
        expect(column).not_to be_nil
        expect(column.value).to be_nil
        expect(column.previous_value).not_to eq("Modifié puis supprimé")
      end
    end
  end

  describe '#event' do
    let(:dossier) { create(:dossier) }
    let(:instructeur) { create(:instructeur) }

    it do
      dossier.traitements.passer_en_construction
      expect(dossier.traitements.last.event).to eq(:depose)

      dossier.traitements.usager_submit_en_construction(checkpoint: 'change1')
      expect(dossier.traitements.last.event).to eq(:depose_correction_usager)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:passe_en_instruction)

      dossier.traitements.passer_en_construction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_construction)

      dossier.traitements.usager_submit_en_construction(checkpoint: 'change2')
      expect(dossier.traitements.last.event).to eq(:depose_correction_usager)

      dossier.traitements.usager_submit_en_construction(checkpoint: 'change3')
      expect(dossier.traitements.last.event).to eq(:depose_correction_usager)

      dossier.traitements.instructeur_submit_en_construction(instructeur:, checkpoint: 'change4')
      expect(dossier.traitements.last.event).to eq(:depose_correction_instructeur)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:passe_en_instruction)

      dossier.traitements.accepter(instructeur:)
      expect(dossier.traitements.last.event).to eq(:accepte)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_instruction)

      dossier.traitements.refuser(instructeur:)
      expect(dossier.traitements.last.event).to eq(:refuse)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_instruction)

      dossier.traitements.classer_sans_suite(instructeur:)
      expect(dossier.traitements.last.event).to eq(:classe_sans_suite)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_instruction)

      dossier.traitements.refuser_automatiquement(motivation: 'yolo')
      expect(dossier.traitements.last.event).to eq(:refuse_automatiquement)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_instruction)

      dossier.traitements.accepter_automatiquement
      expect(dossier.traitements.last.event).to eq(:accepte_automatiquement)

      dossier.traitements.passer_en_instruction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_instruction)

      dossier.traitements.passer_en_construction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_construction)

      dossier.traitements.passer_en_instruction
      expect(dossier.traitements.last.event).to eq(:passe_en_instruction_automatiquement)

      # again passer_en_instruction: simulate a bug for some dossiers having multiple consecutive "en instruction" automatic traitements
      dossier.traitements.passer_en_instruction
      expect(dossier.traitements.last.event).to eq(:passe_en_instruction_automatiquement)

      dossier.traitements.accepter(instructeur:)
      expect(dossier.traitements.last.event).to eq(:accepte)

      # passer_en_construction from accepte: simulate a bug for some dossiers
      dossier.traitements.passer_en_construction(instructeur:)
      expect(dossier.traitements.last.event).to eq(:repasse_en_construction)
    end
  end
end
