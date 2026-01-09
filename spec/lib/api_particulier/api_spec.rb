# frozen_string_literal: true

describe APIParticulier::API do
  let(:token) { "d7e9c9f4c3ca00caadde31f50fd4521a" }
  let(:api) { APIParticulier::API.new(token) }

  before { stub_const("API_PARTICULIER_URL", "https://particulier.api.gouv.fr/api") }

  describe "scopes" do
    subject { api.scopes }

    it "doit retourner une liste de scopes" do
      VCR.use_cassette("api_particulier/success/introspect") do
        expect(subject).to contain_exactly(
          'cnaf_adresse',
          'cnaf_allocataires',
          'cnaf_enfants',
          'cnaf_quotient_familial',
          'dgfip_adresse_fiscale_annee',
          'dgfip_adresse_fiscale_taxation',
          'dgfip_annee_impot',
          'dgfip_annee_revenus',
          'dgfip_date_etablissement',
          'dgfip_date_recouvrement',
          'dgfip_declarant1_date_naissance',
          'dgfip_declarant1_nom',
          'dgfip_declarant1_nom_naissance',
          'dgfip_declarant1_prenoms',
          'dgfip_declarant2_date_naissance',
          'dgfip_declarant2_nom',
          'dgfip_declarant2_nom_naissance',
          'dgfip_declarant2_prenoms',
          'dgfip_erreur_correctif',
          'dgfip_impot_revenu_net_avant_corrections',
          'dgfip_montant_impot',
          'dgfip_nombre_parts',
          'dgfip_nombre_personnes_a_charge',
          'dgfip_revenu_brut_global',
          'dgfip_revenu_fiscal_reference',
          'dgfip_revenu_imposable',
          'dgfip_situation_familiale',
          'dgfip_situation_partielle',
          'pole_emploi_identite',
          'pole_emploi_adresse',
          'pole_emploi_contact',
          'pole_emploi_inscription',
          'mesri_identifiant',
          'mesri_identite',
          'mesri_inscription_etudiant',
          'mesri_inscription_autre',
          'mesri_admission',
          'mesri_etablissements'
        )
      end
    end

    it "returns an unauthorized exception" do
      VCR.use_cassette("api_particulier/unauthorized/introspect") do
        begin
          subject
        rescue APIParticulier::Error::Unauthorized => e
          expect(e.message).to include('url: particulier.api.gouv.fr/api/introspect')
          expect(e.message).to include('HTTP error code: 401')
          expect(e.message).to include("Votre jeton d’API n’a pas été trouvé ou n’est pas actif")
        end
      end
    end
  end
end
