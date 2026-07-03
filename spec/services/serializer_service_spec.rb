# frozen_string_literal: true

describe SerializerService do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:champ) { dossier.project_champs_public.first }
  let(:etablissement) { champ.etablissement }

  describe 'champ' do
    subject { SerializerService.champ(champ) }

    describe 'type champ is siret' do
      it '', :slow do
        is_expected.to include("stringValue" => etablissement.siret)
        expect(subject["etablissement"]).to include("siret" => etablissement.siret)
        expect(subject["etablissement"]["entreprise"]).to include("codeEffectifEntreprise" => etablissement.entreprise_code_effectif_entreprise)
      end

      context 'with entreprise_date_creation is nil' do
        before { etablissement.update(entreprise_date_creation: nil) }

        it {
          expect(subject["etablissement"]["entreprise"]).to include("nomCommercial" => etablissement.entreprise_nom_commercial)
          expect(subject["etablissement"]["entreprise"]["dateCreation"]).to be_nil
        }
      end
    end
  end
end
