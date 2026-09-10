# frozen_string_literal: true

# Regression: the engines mounted under the /manager namespace (Flipper UI,
# MaintenanceTasks, Sidekiq::Web) bypass Manager::ApplicationController, so the
# RequiresEnrolledSuperAdminOtp gate never runs for them. A super admin who is
# signed in but has not enrolled OTP must not be able to reach them.
#
# /manager/features (Flipper::UI) stands in for all three: they share the same
# `authenticate :super_admin` route block in config/routes/manager.rb.
describe 'Manager mounted engines require an OTP-enrolled super admin', type: :request do
  subject { get '/manager/features' }

  context 'when the super admin has enrolled OTP' do
    let(:super_admin) { create(:super_admin, otp_required_for_login: true) }

    before { login_as super_admin, scope: :super_admin }

    it 'can reach the engine' do
      subject
      expect(response).not_to have_http_status(:not_found)
    end
  end

  context 'when the super admin has not enrolled OTP' do
    let(:super_admin) { create(:super_admin, otp_required_for_login: false) }

    before { login_as super_admin, scope: :super_admin }

    it 'cannot reach the engine' do
      subject
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when nobody is signed in' do
    it 'is redirected to the super admin sign in' do
      subject
      expect(response).to have_http_status(:found)
      expect(response.location).to end_with('super_admins/sign_in')
    end
  end
end
