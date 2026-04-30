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
  let(:champ) { dossier.champs.first }

  describe 'ensure_legitimate_access' do
    before do
      sign_in user
      request.accept = "application/json"
      request.content_type = "application/json"
    end

    context 'when the champ is not a carte' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text }]) }
      let(:champ) { dossier.project_champs_public.first }

      it 'returns not found' do
        get :index, params: { dossier_id: champ.dossier_id, stable_id: champ.stable_id }, format: :turbo_stream
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'features' do
    let(:feature) { attributes_for(:geo_area, :polygon) }
    let(:geo_area) { create(:geo_area, :selection_utilisateur, :polygon, champ: champ) }

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
          id: geo_area.id,
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
          id: geo_area.id,
        }
      end

      subject { delete :destroy, params: params }

      it do
        expect { subject } .to change { dossier.reload.last_champ_updated_at }
        expect(response).to have_http_status(:no_content)
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
