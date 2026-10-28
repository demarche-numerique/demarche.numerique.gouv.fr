# frozen_string_literal: true

describe Instructeurs::ExportBannersController, type: :controller do
  render_views

  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let!(:export) { create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur) }

  before do
    instructeur.request_export!(export)
    sign_in(instructeur.user)
  end

  describe '#polling' do
    it 'replaces the banner' do
      get :polling, format: :turbo_stream

      expect(response.body).to include('turbo-stream action="replace" target="export-banner"')
      expect(response.body).to include('Votre dernier export est en cours de création.')
    end
  end

  describe '#destroy' do
    it 'dismisses the banner and empties it' do
      delete :destroy, params: { export_id: export.id }, format: :turbo_stream

      expect(instructeur.reload.last_requested_export_dismissed_at).to be_present
      expect(response.body).to include('turbo-stream action="update" target="export-banner"')
    end

    it 'redirects back without JavaScript' do
      request.env['HTTP_REFERER'] = instructeur_procedure_path(procedure)

      delete :destroy, params: { export_id: export.id }

      expect(response).to redirect_to(instructeur_procedure_path(procedure))
    end

    it 'only stamps the caller account for an export it cannot see' do
      foreign = create(:export, :generated)

      delete :destroy, params: { export_id: foreign.id }, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(instructeur.reload.last_requested_export_dismissed_at).to be_nil
      expect(instructeur.colleague_exports_dismissed_at).to be_present
    end
  end
end
