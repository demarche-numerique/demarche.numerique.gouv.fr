# frozen_string_literal: true

describe Administrateurs::JetonsController, type: :controller do
  let(:admin) { administrateurs(:default_admin) }
  let(:procedure) { create(:procedure, administrateur: admin) }

  context 'API Entreprise' do
    before do
      sign_in(admin.user)
    end

    describe 'GET #index' do
      let(:token) { "eyJhbGciOiJub25lIn0.eyJzY29wZXMiOlsiYXR0ZXN0YXRpb25fZmlzY2FsZV9kZ2ZpcCIsIm9wZW5fZGF0YSJdLCJleHAiOjQxMDI0NDQ4MDB9." }
      let(:procedure) { create(:procedure, administrateur: admin, api_entreprise_token: token) }

      subject { get :index, params: { procedure_id: procedure.id } }

      before do
        allow_any_instance_of(APIEntrepriseToken).to receive(:expired_or_expires_soon?).and_return(false)
      end

      it 'assigns decoded scopes for the token' do
        subject
        expect(response).to have_http_status(:success)
        expect(assigns(:api_entreprise_scopes)).to eq(["attestation_fiscale_dgfip", "open_data"])
      end
    end

    describe 'GET #edit_entreprise' do
      let(:procedure) { create(:procedure, administrateur: admin) }

      subject { get :edit_entreprise, params: { procedure_id: procedure.id } }

      it { is_expected.to have_http_status(:success) }
    end

    describe 'PATCH #update_entreprise' do
      let(:procedure) { create(:procedure, administrateur: admin) }
      let(:token) { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
      let(:api_response_body) { nil }

      subject { patch :update_entreprise, params: { procedure_id: procedure.id, procedure: { api_entreprise_token: token } } }

      before do
        if api_response_body
          stub_request(:get, "https://entreprise.api.gouv.fr/privileges")
            .to_return(body: api_response_body, status: api_response_status)
        end
      end

      context 'when jeton is valid' do
        let(:api_response_status) { 200 }
        let(:api_response_body) { File.read('spec/fixtures/files/api_entreprise/privileges.json') }

        it do
          subject
          expect(flash.alert).to be_nil
          expect(flash.notice).to eq('Le jeton a bien été mis à jour')
          expect(procedure.reload.api_entreprise_token.jwt_token).to eq(token)
        end
      end

      context 'when jeton is invalid' do
        let(:api_response_status) { 403 }
        let(:api_response_body) { '' }

        it do
          subject
          expect(flash.alert).to eq("Mise à jour impossible : le jeton n’est pas valide")
          expect(flash.notice).to be_nil
          expect(procedure.reload.api_entreprise_token).not_to eq(token)
        end
      end

      context 'when jeton is not a jwt' do
        let(:token) { "invalid" }

        it do
          subject
          expect(flash.alert).to eq("Mise à jour impossible : le jeton n’est pas valide")
          expect(flash.notice).to be_nil
          expect(procedure.reload.api_entreprise_token).not_to eq(token)
        end
      end
    end

    describe 'DELETE #destroy_entreprise' do
      let(:procedure) { create(:procedure, administrateur: admin) }

      subject { delete :destroy_entreprise, params: { procedure_id: procedure.id } }

      it do
        subject
        expect(flash.notice).to eq("Le jeton API Entreprise a bien été supprimé")
        expect(procedure.reload.specific_api_entreprise_token?).to eq(false)
      end
    end
  end

  context 'API Particulier' do
    before do
      stub_const("API_PARTICULIER_URL", "https://particulier.api.gouv.fr/api")

      sign_in(admin.user)
    end

    describe "GET #edit_particulier" do
      render_views

      subject { get :edit_particulier, params: { procedure_id: procedure.id } }

      it do
        is_expected.to have_http_status(:success)
        expect(subject.body).to have_content('Jeton API particulier')
      end
    end

    describe "PATCH #update_particulier" do
      let(:params) { { procedure_id: procedure.id, procedure: { api_particulier_token: token } } }

      subject { patch :update_particulier, params: params }

      context "when jeton has a valid shape" do
        let(:token) { "d7e9c9f4c3ca00caadde31f50fd4521a" }
        before do
          VCR.use_cassette(cassette) do
            subject
          end
        end

        context "and the api response is a success" do
          let(:cassette) { "api_particulier/success/introspect" }
          let(:procedure) { create(:procedure, administrateur: admin, api_particulier_sources: { cnaf: { allocataires: ['nomPrenom'] } }) }

          it 'saves the jeton' do
            expect(flash.alert).to be_nil
            expect(flash.notice).to eq("Le jeton a bien été mis à jour")
            procedure.reload
            expect(procedure.api_particulier_token).to eql(token)
            expect(procedure.api_particulier_scopes).to contain_exactly(
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
            expect(procedure.api_particulier_sources).to be_empty
          end
        end

        context "and the api response is a success but with an empty scopes" do
          let(:cassette) { "api_particulier/success/introspect_empty_scopes" }

          it 'rejects the jeton' do
            expect(flash.alert).to include("le jeton n’a pas acces aux données")
            expect(flash.notice).to be_nil
            expect(procedure.reload.api_particulier_token).not_to eql(token)
          end
        end

        context "and the api response is not unauthorized" do
          let(:cassette) { "api_particulier/unauthorized/introspect" }

          it 'rejects the jeton' do
            expect(flash.alert).to include("Mise à jour impossible : le jeton n’a pas été trouvé ou n’est pas actif")
            expect(flash.notice).to be_nil
            expect(procedure.reload.api_particulier_token).not_to eql(token)
          end
        end
      end

      context "when jeton is invalid and no network call is made" do
        let(:token) { "jet0n 1nvalide" }

        before { subject }

        it 'rejects the jeton' do
          expect(flash.alert.first).to include("pas le bon format")
          expect(flash.notice).to be_nil
          expect(procedure.reload.api_particulier_token).not_to eql(token)
        end
      end
    end

    describe 'DELETE #destroy_particulier' do
      let(:procedure) { create(:procedure, administrateur: admin, api_particulier_token:, api_particulier_scopes:, api_particulier_sources: { cnaf: { allocataires: ['nomPrenom'] } }) }
      let(:api_particulier_token) { "d7e9c9f4c3ca00caadde31f50fd4521a" }
      let(:api_particulier_scopes) { ['cnaf_allocataires', 'cnaf_adresse'] }

      subject { delete :destroy_particulier, params: { procedure_id: procedure.id } }

      it do
        subject
        expect(flash.notice).to eq("Le jeton API Particulier a bien été supprimé")
        expect(procedure.reload.api_particulier_token).to eq(nil)
        expect(procedure.reload.api_particulier_sources).to eq(nil)
        expect(procedure.reload.api_particulier_scopes).to eq(nil)
      end
    end
  end
end
