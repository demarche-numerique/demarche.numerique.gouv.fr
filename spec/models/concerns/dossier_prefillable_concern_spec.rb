# frozen_string_literal: true

RSpec.describe DossierPrefillableConcern do
  describe '.prefill!' do
    let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs:, private_type_de_champs:) }
    let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure: procedure) }
    let(:public_type_de_champs) { [] }
    let(:private_type_de_champs) { [] }
    let(:identity_attributes) { {} }
    let(:values) { [] }

    subject(:fill) do
      dossier.prefill!(values, identity_attributes)
      dossier.reload
    end

    shared_examples 'a dossier marked as prefilled' do
      it 'marks the dossier as prefilled' do
        expect { fill }.to change { dossier.reload.prefilled }.from(nil).to(true)
      end
    end

    context "when dossier is for individual" do
      let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs:, private_type_de_champs:) }
      let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure: procedure) }

      context "when identity_attributes is present" do
        let(:identity_attributes) { { "prenom" => "Prénom", "nom" => "Nom", "gender" => "Mme" } }

        it_behaves_like 'a dossier marked as prefilled'

        it "updates the individual" do
          fill
          expect(dossier.individual.prenom).to eq("Prénom")
          expect(dossier.individual.nom).to eq("Nom")
          expect(dossier.individual.gender).to eq("Mme")
        end
      end

      context 'when champs_attributes is empty' do
        it "doesn't mark the dossier as prefilled" do
          expect { fill }.not_to change { dossier.reload.prefilled }.from(nil)
        end

        it "doesn't change champs_public" do
          expect { fill }.not_to change { dossier.root_champs_public.to_a }
        end
      end

      context 'when champs_attributes has values' do
        context 'when the champs are valid' do
          let(:public_type_de_champs) { [{ type: :text }, { type: :phone }] }
          let(:private_type_de_champs) { [{ type: :text }] }

          let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
          let(:value_1) { "any value" }
          let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

          let(:type_de_champ_2) { procedure.published_revision.public_root_type_de_champs.second }
          let(:value_2) { "33612345678" }
          let(:champ_2) { find_champ_by_stable_id(dossier, type_de_champ_2.stable_id) }

          let(:type_de_champ_3) { procedure.published_revision.private_root_type_de_champs.first }
          let(:value_3) { "some value" }
          let(:champ_3) { find_champ_by_stable_id(dossier, type_de_champ_3.stable_id) }

          let(:values) { [[champ_1, { value: value_1 }], [champ_2, { value: value_2 }], [champ_3, { value: value_3 }]] }

          it_behaves_like 'a dossier marked as prefilled'

          it "updates the champs with the new values and mark them as prefilled" do
            fill

            expect(dossier.root_champs_public.first.value).to eq(value_1)
            expect(dossier.root_champs_public.first.prefilled).to eq(true)
            expect(dossier.root_champs_public.last.value).to eq(value_2)
            expect(dossier.root_champs_public.last.prefilled).to eq(true)
            expect(dossier.root_champs_private.first.value).to eq(value_3)
            expect(dossier.root_champs_private.first.prefilled).to eq(true)
          end
        end

        context 'when a champ is invalid' do
          let(:public_type_de_champs) { [{ type: :phone }] }
          let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
          let(:value) { "a non phone value" }
          let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

          let(:values) { [[champ_1, { value: value }]] }

          it_behaves_like 'a dossier marked as prefilled'

          it "still updates the champ" do
            expect { fill }.to change { dossier.root_champs_public.first.value }.from(nil).to(value)
          end

          it "still marks it as prefilled" do
            expect { fill }.to change { dossier.root_champs_public.first.prefilled }.from(nil).to(true)
          end
        end
      end
    end

    context "when dossier is for etablissement" do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }
      let(:dossier) { create(:dossier, :brouillon, procedure: procedure) }

      context 'when champs_attributes has values' do
        context 'when the champs are valid' do
          let(:public_type_de_champs) { [{ type: :text }] }
          let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
          let(:value_1) { "any value" }
          let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }
          let(:values) { [[champ_1, { value: value_1 }]] }

          it "updates the champs with the new values and mark them as prefilled" do
            fill
            expect(dossier.root_champs_public.first.value).to eq(value_1)
            expect(dossier.individual).to be_nil # Fix #9486
          end

          it_behaves_like 'a dossier marked as prefilled'
        end
      end
    end

    context 'when dossier contains a pre_rempli champ' do
      let(:public_type_de_champs) { [{ type: :pre_rempli }] }
      let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
      let(:value_1) { "valeur pré-remplie" }
      let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }
      let(:values) { [[champ_1, { value: value_1 }]] }

      it_behaves_like 'a dossier marked as prefilled'

      it "assigns the value correctly via prefill" do
        fill
        expect(dossier.root_champs_public.first.value).to eq(value_1)
        expect(dossier.root_champs_public.first.prefilled).to eq(true)
      end
    end

    context 'when a prefill value was rejected by the Prefill screening' do
      # Regression: rejected prefill values used to be assigned to the champ while
      # screening with champ.valid?(:prefill), and could leak to the database
      # through the dossier champ_data autosave when a valid champ triggered a save.
      let(:public_type_de_champs) { [{ type: :text }, { type: :date }] }
      let(:text_type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
      let(:date_type_de_champ) { procedure.published_revision.public_root_type_de_champs.second }
      let(:params) do
        {
          "champ_#{text_type_de_champ.to_typed_id_for_query}" => "any value",
          "champ_#{date_type_de_champ.to_typed_id_for_query}" => "not a date",
        }
      end
      let(:values) { PrefillChamps.new(dossier, params).to_a }

      it 'prefills the valid champ and does not persist the rejected value' do
        fill
        expect(find_champ_by_stable_id(dossier, text_type_de_champ.stable_id).value).to eq("any value")
        expect(find_champ_by_stable_id(dossier, date_type_de_champ.stable_id)&.value).to be_nil
      end
    end

    context 'when dossier contains an advanced (referentiel-backed) drop_down_list' do
      # Regression: prefilling such a champ with a human label used to be wiped
      # to nil by the store_referentiel before_save (which only matched item ids).
      let(:referentiel) { create(:csv_referentiel, :with_items) }
      let(:public_type_de_champs) { [{ type: :drop_down_list, drop_down_mode: 'advanced', referentiel: }] }
      let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
      let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }
      let(:params) { { "champ_#{type_de_champ_1.to_typed_id_for_query}" => "fromage" } }
      let(:values) { PrefillChamps.new(dossier, params).to_a }

      it 'resolves the label to its item id and keeps the value after save' do
        fill
        champ = find_champ_by_stable_id(dossier, type_de_champ_1.stable_id)
        expect(champ.value).to eq(referentiel.items.first.id.to_s)
        expect(champ.prefilled).to eq(true)
        expect(champ.referentiel_item_column_values).to eq([["option", "fromage"], ["calorie (kcal)", "145"], ["poids (g)", "60"]])
      end
    end

    context 'when dossier contains champs with external_id' do
      let(:public_type_de_champs) { [{ type: :siret }] }
      let(:values) { [[champ_1, { external_id: value_1 }]] }
      let(:type_de_champ_1) { procedure.published_revision.public_root_type_de_champs.first }
      let(:value_1) { "130 025 265 00013" }
      let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

      it "updates the champs with the new values and mark them as prefilled" do
        expect { fill }.to have_enqueued_job(ChampFetchExternalDataJob).once
      end
    end

    private

    def find_champ_by_stable_id(dossier, stable_id)
      dossier.champ_data.find_by(stable_id:)
    end
  end
end
