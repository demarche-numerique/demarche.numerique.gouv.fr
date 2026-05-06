# frozen_string_literal: true

RSpec.describe API::Public::V1::JSONDescriptionProceduresController, type: :controller do
  include Rails.application.routes.url_helpers

  describe '#show' do
    let(:procedure) { create(:procedure, :published, :with_type_de_champ) }
    subject(:show_request) do
      get :show, params: params
    end

    before { show_request }

    context 'the procedure is found' do
      let(:params) { { path: procedure.path } }
      let(:expected_response) do
        API::V2::Schema.execute(API::V2::StoredQuery.get('ds-query-v2'),
          variables: {
            demarche: { "number": procedure.id },
            includeRevision: true,
          },
          operation_name: "getDemarcheDescriptor")
          .to_h.dig("data", "demarcheDescriptor").to_json
      end

      it do
        expect(response).to have_http_status(:success)
        expect(response.body).to eq(expected_response)
      end
    end

    context "the procedure is not found" do
      let(:params) { { path: "error" } }

      it do
        expect(response).to have_http_status(:not_found)
        expect(response).to have_failed_with("procedure error is not found")
      end
    end

    context "when the opendata procedure has private annotations" do
      let(:procedure) { create(:procedure, :published, opendata: true) }
      let(:params) { { path: procedure.path } }

      it "does not expose the private annotation libelle in the public schema" do
        create(:type_de_champ_text, :private, procedure: procedure, libelle: "annotation interne secrete")
        get :show, params: params

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("annotation interne secrete")
      end
    end
  end
end
