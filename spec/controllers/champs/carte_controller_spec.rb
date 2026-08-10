# frozen_string_literal: true

describe Champs::CarteController, type: :controller do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :carte, options: { cadastres: true } }]) }
  let(:dossier) { create(:dossier, user: user, procedure: procedure) }
  let(:params) do
    {
      dossier: {
        champs_public_attributes: {
          champ.public_id => { value: value },
        },
      },
      position: '1',
      dossier_id: champ.dossier_id,
      stable_id: champ.stable_id,
    }
  end
  let(:champ) { dossier.champ_data.first }

  describe 'ensure_legitimate_access' do
    before do
      sign_in user
      request.accept = "application/json"
      request.content_type = "application/json"
    end

    context 'when the champ is not a carte' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text }]) }
      let(:champ) { dossier.root_public_champs.first }

      it 'returns not found' do
        get :index, params: { dossier_id: champ.dossier_id, stable_id: champ.stable_id }, format: :turbo_stream
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'features' do
    let(:feature) { attributes_for(:geo_area, :polygon) }
    let(:geo_area) { create(:geo_area, :selection_utilisateur, :polygon, champ_data: champ) }

    before do
      sign_in user
      request.accept = "application/json"
      request.content_type = "application/json"
    end

    describe 'POST #create' do
      subject { post :create, params: params }

      context 'when success (selection utilisateur)' do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            feature: feature,
            source: GeoArea.sources.fetch(:selection_utilisateur),
          }
        end

        it do
          expect { subject } .to change { dossier.reload.last_champ_updated_at }
          expect(response).to have_http_status(:created)
        end
      end

      context 'when success (cadastre)' do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            feature: feature,
            source: GeoArea.sources.fetch(:cadastre),
          }
        end

        it do
          expect { subject } .to change { dossier.reload.last_champ_updated_at }
          expect(response).to have_http_status(:created)
        end

        it 'enqueues a FetchCadastreRealGeometryJob' do
          expect { subject }.to have_enqueued_job(FetchCadastreRealGeometryJob)
        end
      end

      context 'error' do
        let(:feature) { attributes_for(:geo_area, :invalid_point) }
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            feature: feature,
            source: GeoArea.sources.fetch(:selection_utilisateur),
          }
        end

        it do
          expect { subject } .not_to change { dossier.reload.last_champ_updated_at }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe 'PATCH #update' do
      let(:params) do
        {
          dossier_id: champ.dossier_id,
          stable_id: champ.stable_id,
          id: geo_area.to_feature[:properties][:id],
          feature: feature,
        }
      end

      subject { patch :update, params: params }

      context 'update geometry' do
        it do
          expect { subject } .to change { dossier.reload.last_champ_updated_at }
          expect(response).to have_http_status(:no_content)
        end
      end

      context 'update description' do
        let(:feature) do
          {
            properties: {
              description: 'un point',
            },
          }
        end

        it do
          subject
          expect(response.status).to eq 204
          expect(geo_area.reload.description).to eq('un point')
        end
      end

      context 'error' do
        let(:feature) { attributes_for(:geo_area, :invalid_point) }

        it do
          expect { subject } .not_to change { dossier.reload.last_champ_updated_at }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe 'DELETE #destroy' do
      let(:params) do
        {
          dossier_id: champ.dossier_id,
          stable_id: champ.stable_id,
          id: geo_area.to_feature[:properties][:id],
        }
      end

      before { geo_area }

      subject { delete :destroy, params: params }

      it do
        expect { subject }.to change { dossier.reload.last_champ_updated_at }
        expect(response).to have_http_status(:no_content)
      end

      it { expect { subject }.to change { GeoArea.count }.by(-1) }

      context 'en_construction' do
        before do
          dossier.reload
          dossier.passer_en_construction!
        end

        it do
          expect { subject }.to change { GeoArea.count }.by(0) # +1 clone, -1 delete = net 0
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'as an invited user on a dossier en_construction' do
      let(:invited_user) { create(:user) }
      let(:dossier) { create(:dossier, :en_construction, user: user, procedure: procedure) }

      before do
        create(:invite, dossier: dossier, user: invited_user, email: invited_user.email)
        sign_in invited_user
      end

      describe 'POST #create' do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            feature: feature,
            source: GeoArea.sources.fetch(:selection_utilisateur),
          }
        end

        subject { post :create, params: params }

        it 'creates the geo area' do
          expect { subject }.to change { GeoArea.count }.by(1)
          expect(response).to have_http_status(:created)
        end
      end

      describe 'PATCH #update' do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            id: geo_area.to_feature[:properties][:id],
            feature: feature,
          }
        end

        subject { patch :update, params: params }

        context 'geometry' do
          let(:feature) { attributes_for(:geo_area, :point) }

          it 'updates the geo area' do
            subject
            expect(response).to have_http_status(:no_content)
            expect(GeoArea.where("geometry->>'type' = 'Point'")).to exist
          end
        end

        context 'description' do
          let(:feature) { { properties: { description: 'un point' } } }

          it 'updates the geo area' do
            subject
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      describe 'DELETE #destroy' do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            id: geo_area.to_feature[:properties][:id],
          }
        end

        before { geo_area }

        subject { delete :destroy, params: params }

        it 'destroys the geo area' do
          subject
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'GET #index' do
      render_views

      before do
        get :index, params: params, format: :turbo_stream
      end

      context 'without focus' do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
          }
        end

        it 'updates the list' do
          expect(response.body).not_to include("map:feature:focus")
          expect(response.status).to eq 200
        end
      end

      context "update list and focus" do
        let(:params) do
          {
            dossier_id: champ.dossier_id,
            stable_id: champ.stable_id,
            focus: true,
          }
        end

        it 'updates the list and focuses the map' do
          expect(response.body).to include(ActionView::RecordIdentifier.dom_id(champ, :geo_areas))
          expect(response.body).to include("map:feature:focus")
          expect(response.status).to eq 200
        end
      end
    end
  end
end
