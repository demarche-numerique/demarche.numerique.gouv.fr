# frozen_string_literal: true

describe DossierExportConcern do
  describe "champ_values_for_export" do
    context 'with integer_number' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :integer_number, libelle: 'c1' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:integer_number_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find(&:integer_number?) }

      it 'give me back my decimal number' do
        dossier
        expect {
          integer_number_type_de_champ.update(type_champ: :decimal_number)
        }.to change { dossier.reload.champ_values_for_export(Procedure.find(procedure.id).type_de_champs_for_procedure_export, format: :xlsx) }
          .from([["c1", 42]]).to([["c1", 42.0]])
      end
    end
    context 'with a unconditionnal procedure' do
      let(:procedure) { create(:procedure, public_type_de_champs:, zones: [create(:zone)]) }
      let(:public_type_de_champs) do
        [
          { type: :text },
          { type: :datetime },
          { type: :yes_no },
          { type: :explication },
          { type: :communes },
          { type: :repetition, children: [{ type: :text }] },
        ]
      end

      let(:text_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:text) } }
      let(:yes_no_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:yes_no) } }
      let(:datetime_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:datetime) } }
      let(:explication_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:explication) } }
      let(:commune_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:communes) } }
      let(:repetition_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:repetition) } }
      let(:repetition_champ) { dossier.root_champs_public.find(&:repetition?) }
      let(:repetition_second_revision_champ) { dossier_second_revision.root_champs_public.find(&:repetition?) }
      let(:dossier) { create(:dossier, procedure: procedure) }
      let(:dossier_second_revision) { create(:dossier, procedure: procedure) }
      let(:dossier_champ_values_for_export) { dossier.champ_values_for_export(procedure.type_de_champs_for_procedure_export, format: :xlsx) }
      let(:dossier_second_revision_champ_values_for_export) { dossier_second_revision.champ_values_for_export(procedure.type_de_champs_for_procedure_export, format: :xlsx) }

      context "when procedure published" do
        before do
          procedure.publish!(procedure.administrateurs.first)
          dossier
          procedure.draft_revision.remove_type_de_champ(text_type_de_champ.stable_id)
          procedure.draft_revision.add_type_de_champ(type_champ: TypeDeChamp.type_champs.fetch(:text), libelle: 'New text field', after_stable_id: repetition_type_de_champ.stable_id)
          procedure.draft_revision.find_and_ensure_exclusive_use(yes_no_type_de_champ.stable_id).update(libelle: 'Updated yes/no')
          procedure.draft_revision.find_and_ensure_exclusive_use(commune_type_de_champ.stable_id).update(libelle: 'Commune de naissance')
          procedure.draft_revision.find_and_ensure_exclusive_use(repetition_type_de_champ.stable_id).update(libelle: 'Repetition')
          procedure.publish_revision!(procedure.administrateurs.first)
          dossier.reload
          procedure.reload
        end

        it "should have champs from all revisions" do
          expect(dossier.public_root_type_de_champs.map(&:libelle)).to eq([text_type_de_champ.libelle, datetime_type_de_champ.libelle, "Yes/no", explication_type_de_champ.libelle, commune_type_de_champ.libelle, repetition_type_de_champ.libelle])
          expect(dossier_second_revision.public_root_type_de_champs.map(&:libelle)).to eq([datetime_type_de_champ.libelle, "Updated yes/no", explication_type_de_champ.libelle, 'Commune de naissance', "Repetition", "New text field"])
          # the champ removed since comes last
          expect(dossier_champ_values_for_export.map { |(libelle)| libelle }).to eq([datetime_type_de_champ.libelle, "Updated yes/no", "Commune de naissance", "Commune de naissance (Code INSEE)", "Commune de naissance (Département)", "New text field", text_type_de_champ.libelle])
          expect(dossier_champ_values_for_export).to eq(dossier_second_revision_champ_values_for_export)
        end

        context 'within a repetition having a type de champs commune (multiple values for export)' do
          it 'works' do
            proc_test = create(:procedure)

            draft = proc_test.draft_revision

            tdc_repetition = draft.add_type_de_champ(type_champ: :repetition, libelle: "repetition")
            draft.add_type_de_champ(type_champ: :communes, libelle: "communes", parent_stable_id: tdc_repetition.stable_id)

            dossier_test = create(:dossier, procedure: proc_test)
            type_champs = proc_test.aggregated_type_de_champs.type_de_champ(tdc_repetition.stable_id).fillable_children
            expect(type_champs.size).to eq(1)
            expect(dossier_test.champ_values_for_export(type_champs, format: :xlsx).size).to eq(3)
          end
        end

        context 'for dossier having a champ not in his revision' do
          let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
          let(:dossier_second_revision) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

          it 'should see champ' do
            expect do
              dossier.rebase!
              dossier.reload
            end.not_to change { dossier.champ_values_for_export(procedure.type_de_champs_for_procedure_export, format: :xlsx) }
          end
        end
      end

      context "when procedure brouillon" do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }, { type: :explication }]) }

        it "should not contain non-exportable types de champ" do
          expect(dossier_champ_values_for_export.map { |(libelle)| libelle }).to eq([text_type_de_champ.libelle])
        end
      end
    end

    context 'with a procedure with a condition' do
      include Logic
      let(:type_de_champs) { [{ type: :yes_no }, { type: :text }] }
      let(:procedure) { create(:procedure, public_type_de_champs: type_de_champs) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:yes_no_tdc) { procedure.active_revision.public_root_type_de_champs.first }
      let(:text_tdc) { procedure.active_revision.public_root_type_de_champs.second }
      let(:tdcs) { dossier.root_champs_public.map(&:type_de_champ) }

      subject { dossier.champ_values_for_export(tdcs, format: :xlsx) }

      before do
        text_tdc.update(condition: ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))

        yes_no, text = dossier.root_champs_public
        yes_no.update(value: yes_no_value)
        text.update(value: 'text')
      end

      context 'with a champ visible' do
        let(:yes_no_value) { 'true' }

        it { is_expected.to eq([[yes_no_tdc.libelle, "Oui"], [text_tdc.libelle, "text"]]) }
      end

      context 'with a champ invisible' do
        let(:yes_no_value) { 'false' }

        it { is_expected.to eq([[yes_no_tdc.libelle, "Non"], [text_tdc.libelle, nil]]) }
      end

      context 'with another revision' do
        let(:tdc_from_another_revision) { create(:type_de_champ_communes, libelle: 'commune', condition: ds_eq(constant(true), constant(true))) }
        let(:tdcs) { dossier.root_champs_public.map(&:type_de_champ) << tdc_from_another_revision }
        let(:yes_no_value) { 'true' }

        let(:expected) do
          [
            [yes_no_tdc.libelle, "Oui"],
            [text_tdc.libelle, "text"],
            ["commune", nil],
            ["commune (Code INSEE)", nil],
            ["commune (Département)", nil],
          ]
        end

        it { is_expected.to eq(expected) }
      end
    end
  end

  describe "#spreadsheet_columns" do
    before_all { seed "cases/sva" }

    let(:dossier) { dossiers.brouillon }

    context 'user france connected' do
      let(:dossier) { build(:dossier, user: build(:user, france_connect_informations: [build(:france_connect_information)]), procedure: procedures.individual) }
      it { expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(["FranceConnect ?", true]) }
    end

    context 'user not france connected' do
      let(:dossier) { build(:dossier, procedure: procedures.individual) }
      it { expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(["FranceConnect ?", false]) }
    end

    context 'for_individual' do
      let(:dossier) { dossiers.brouillon }
      it do
        expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(["Dépôt pour un tiers", :for_tiers])
        expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(['Nom du mandataire', :mandataire_last_name])
        expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(['Prénom du mandataire', :mandataire_first_name])
      end
    end

    it { expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(["État du dossier", "Brouillon"]) }

    context 'procedure sva' do
      let(:dossier) { build(:dossier, :en_instruction, procedure: procedures.sva) }

      it { expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(["Date décision SVA", :sva_svr_decision_on]) }
    end

    context 'procedure svr' do
      let(:dossier) { build(:dossier, :en_instruction, procedure: procedures.svr) }

      it { expect(dossier.spreadsheet_columns(type_de_champs: [])).to include(["Date décision SVR", :sva_svr_decision_on]) }
    end
  end
end
