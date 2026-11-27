# frozen_string_literal: true

describe Instructeurs::ExportBannersController, type: :controller do
  render_views

  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let!(:export) { create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur) }

  before do
    sign_in(instructeur.user)
  end

  describe '#polling' do
    it 'replaces the banner' do
      get :polling, format: :turbo_stream

      expect(response.body).to include('turbo-stream action="replace" target="export-banner"')
      expect(response.body).to include('Votre dernier export est en cours de création.')
    end

    it 'does not move the focus' do
      get :polling, format: :turbo_stream

      expect(response.body).not_to include('action="focus"')
    end

    it 'hides a ready colleague export of a ProConnect restricted procedure without a ProConnect session' do
      colleague = create(:instructeur, groupe_instructeurs: [gi])
      colleague_export = create(:export, groupe_instructeurs: [gi], user_profile: colleague)
      colleague_export.file.attach(io: StringIO.new('x'), filename: 'e.csv')
      colleague_export.update!(job_status: :generated)
      procedure.update!(pro_connect_restriction: :instructeurs)

      get :polling, format: :turbo_stream

      expect(response.body).to include('turbo-stream action="replace" target="export-banner"')
      expect(response.body).not_to include(colleague_export.file.url)
      expect(response.body).not_to include('est prêt')
    end
  end

  describe '#destroy' do
    it 'dismisses the banner and empties it' do
      delete :destroy, format: :turbo_stream

      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      expect(response.body).to include('turbo-stream action="update" target="export-banner"')
      expect(response.body).not_to include('action="focus"')
    end

    it 'redirects back without JavaScript' do
      request.env['HTTP_REFERER'] = instructeur_procedure_path(procedure)

      delete :destroy

      expect(response).to redirect_to(instructeur_procedure_path(procedure))
    end

    it 'only closes the banner for the caller' do
      colleague = create(:instructeur, groupe_instructeurs: [gi])
      colleague_export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: colleague)

      delete :destroy, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      expect(colleague.reload.export_for_banner(pro_connect: false)).to eq(colleague_export)
    end
  end
end
