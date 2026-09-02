# frozen_string_literal: true

describe Administrateurs::JetonsController, type: :controller do
  let(:admin) { administrateurs.default }
  let(:procedure) { create(:procedure, administrateur: admin) }

  context 'API Entreprise' do
    before do
      sign_in(admin.user)
    end
    describe 'GET #edit_entreprise' do
      let(:procedure) { create(:procedure, administrateur: admin) }

      subject { get :edit_entreprise, params: { procedure_id: procedure.id } }

      it { is_expected.to have_http_status(:success) }

      # Le jeton global de l'instance n'est pas à la main de l'administrateur : lui
      # annoncer qu'il doit le renouveler n'a pas de sens.
      context 'when only the instance-wide token is set, and expired' do
        render_views

        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('API_ENTREPRISE_KEY').and_return(JWT.encode({ exp: 2.days.ago.to_i }, nil, 'none'))
        end

        it { expect(subject.body).not_to include('Merci de le renouveler') }
      end

      # La page où atterrit l'administrateur depuis le mail « n’est pas valide ».
      context 'when the procedure token cannot be decoded' do
        render_views

        let(:procedure) do
          create(:procedure, administrateur: admin).tap do
            it.api_entreprise_token = 'azertyuiopqsdfgh'
            it.save(validate: false)
          end
        end

        it { expect(subject.body).to include('n’est pas valide') }
      end
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
      stub_const("API_PARTICULIER_URL", "https://particulier.api.gouv.fr")

      sign_in(admin.user)
    end

    # La page qui liste les jetons de la démarche et leur état.
    describe "GET #index" do
      render_views

      let(:procedure) do
        create(:procedure, administrateur: admin).tap do
          it.api_particulier_token = 'azertyuiopqsdfgh'
          it.save(validate: false)
        end
      end

      subject { get :index, params: { procedure_id: procedure.id } }

      it { expect(subject.body).to have_content('Jeton invalide') }
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
      subject { patch :update_particulier, params: { procedure_id: procedure.id, procedure: { api_particulier_token: token } } }

      context "when jeton is a valid JWT" do
        let(:token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }

        it 'saves the jeton' do
          subject
          expect(flash.alert).to be_nil
          expect(flash.notice).to eq("Le jeton a bien été mis à jour")
        end
      end

      context "when jeton has expired" do
        let(:token) { JWT.encode({ exp: 2.days.ago.to_i }, nil, 'none') }

        it 'rejects the jeton' do
          subject
          expect(flash.alert).to eq("Mise à jour impossible : ce jeton a expiré")
          expect(procedure.reload.api_particulier_token?).to be(false)
        end
      end

      context "when jeton is not a JWT" do
        # Le cas de RAILS-MGX : un administrateur avait saisi n'importe quoi.
        let(:token) { "azertyuiopqsdfgh" }

        it 'rejects the jeton' do
          subject
          expect(flash.alert).to eq("Mise à jour impossible : le jeton n’est pas valide")
          expect(flash.notice).to be_nil
          expect(procedure.reload.api_particulier_token?).to be(false)
        end
      end
    end

    describe 'DELETE #destroy_particulier' do
      let(:procedure) { create(:procedure, administrateur: admin, api_particulier_token:) }
      let(:api_particulier_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }

      subject { delete :destroy_particulier, params: { procedure_id: procedure.id } }

      it do
        subject
        expect(flash.notice).to eq("Le jeton API Particulier a bien été supprimé")
        expect(procedure.reload.api_particulier_token?).to eq(false)
      end
    end
  end
end
