# frozen_string_literal: true

RSpec.describe DossierPrefillableConcern do
  describe '.prefill!' do
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:, types_de_champ_private:) }
    let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure: procedure) }
    let(:types_de_champ_public) { [] }
    let(:types_de_champ_private) { [] }
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
      let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:, types_de_champ_private:) }
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
          expect { fill }.not_to change { dossier.project_champs_public.to_a }
        end
      end

      context 'when champs_attributes has values' do
        context 'when the champs are valid' do
          let(:types_de_champ_public) { [{ type: :text }, { type: :phone }] }
          let(:types_de_champ_private) { [{ type: :text }] }

          let(:type_de_champ_1) { procedure.published_revision.types_de_champ_public.first }
          let(:value_1) { "any value" }
          let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

          let(:type_de_champ_2) { procedure.published_revision.types_de_champ_public.second }
          let(:value_2) { "33612345678" }
          let(:champ_2) { find_champ_by_stable_id(dossier, type_de_champ_2.stable_id) }

          let(:type_de_champ_3) { procedure.published_revision.types_de_champ_private.first }
          let(:value_3) { "some value" }
          let(:champ_3) { find_champ_by_stable_id(dossier, type_de_champ_3.stable_id) }

          let(:values) { [[champ_1, { value: value_1 }], [champ_2, { value: value_2 }], [champ_3, { value: value_3 }]] }

          it_behaves_like 'a dossier marked as prefilled'

          it "updates the champs with the new values and mark them as prefilled" do
            fill

            expect(dossier.project_champs_public.first.value).to eq(value_1)
            expect(dossier.project_champs_public.first.prefilled).to eq(true)
            expect(dossier.project_champs_public.last.value).to eq(value_2)
            expect(dossier.project_champs_public.last.prefilled).to eq(true)
            expect(dossier.project_champs_private.first.value).to eq(value_3)
            expect(dossier.project_champs_private.first.prefilled).to eq(true)
          end
        end

        context 'when a champ is invalid' do
          let(:types_de_champ_public) { [{ type: :phone }] }
          let(:type_de_champ_1) { procedure.published_revision.types_de_champ_public.first }
          let(:value) { "a non phone value" }
          let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

          let(:values) { [[champ_1, { value: value }]] }

          it_behaves_like 'a dossier marked as prefilled'

          it "still updates the champ" do
            expect { fill }.to change { dossier.project_champs_public.first.value }.from(nil).to(value)
          end

          it "still marks it as prefilled" do
            expect { fill }.to change { dossier.project_champs_public.first.prefilled }.from(nil).to(true)
          end
        end
      end
    end

    context "when dossier is for etablissement" do
      let(:procedure) { create(:procedure, :published, types_de_champ_public:, types_de_champ_private:) }
      let(:dossier) { create(:dossier, :brouillon, procedure: procedure) }

      context 'when champs_attributes has values' do
        context 'when the champs are valid' do
          let(:types_de_champ_public) { [{ type: :text }] }
          let(:type_de_champ_1) { procedure.published_revision.types_de_champ_public.first }
          let(:value_1) { "any value" }
          let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }
          let(:values) { [[champ_1, { value: value_1 }]] }

          it "updates the champs with the new values and mark them as prefilled" do
            fill
            expect(dossier.project_champs_public.first.value).to eq(value_1)
            expect(dossier.individual).to be_nil # Fix #9486
          end

          it_behaves_like 'a dossier marked as prefilled'
        end
      end
    end

    context 'when dossier contains a pre_rempli champ' do
      let(:types_de_champ_public) { [{ type: :pre_rempli }] }
      let(:type_de_champ_1) { procedure.published_revision.types_de_champ_public.first }
      let(:value_1) { "valeur pré-remplie" }
      let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }
      let(:values) { [[champ_1, { value: value_1 }]] }

      it_behaves_like 'a dossier marked as prefilled'

      it "assigns the value correctly via prefill" do
        fill
        expect(dossier.project_champs_public.first.value).to eq(value_1)
        expect(dossier.project_champs_public.first.prefilled).to eq(true)
      end
    end

    context 'when dossier contains champs with external_id' do
      let(:types_de_champ_public) { [{ type: :siret }] }
      let(:values) { [[champ_1, { external_id: value_1 }]] }
      let(:type_de_champ_1) { procedure.published_revision.types_de_champ_public.first }
      let(:value_1) { "130 025 265 00013" }
      let(:champ_1) { find_champ_by_stable_id(dossier, type_de_champ_1.stable_id) }

      it "updates the champs with the new values and mark them as prefilled" do
        expect { fill }.to have_enqueued_job(ChampFetchExternalDataJob).once
      end
    end

    private

    def find_champ_by_stable_id(dossier, stable_id)
      # Production builds prefill champs through champ_for_update (writable).
      dossier.project_champs.find { it.stable_id == stable_id }&.writable!
    end
  end
end
