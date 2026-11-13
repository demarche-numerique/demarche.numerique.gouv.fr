# frozen_string_literal: true

describe 'super admin session lifetime', type: :request do
  let(:super_admin) { create(:super_admin, :with_otp) }

  def sign_in_super_admin(remember_me: false) = post_super_admin_session(super_admin, remember_me:)

  # Busy the whole time on purpose: an inactivity timeout would let this pass.
  it 'signs out a super admin who never stopped working, after a day' do
    sign_in_super_admin

    3.times do
      travel 6.hours
      get manager_root_path
      expect(response).to have_http_status(:ok)
    end

    travel 7.hours # 25 hours since signing in

    get manager_root_path

    expect(response).to redirect_to(new_super_admin_session_path)
  end

  it 'leaves them alone at 23 hours' do
    sign_in_super_admin

    travel 23.hours
    get manager_root_path

    expect(response).to have_http_status(:ok)
  end

  it 'gives no remember-me cookie a chance to reopen the session' do
    sign_in_super_admin(remember_me: true)

    expect(SuperAdmin.devise_modules).not_to include(:rememberable)
    expect(cookies['remember_super_admin_token']).to be_blank

    travel 25.hours
    get manager_root_path

    expect(response).to redirect_to(new_super_admin_session_path)
  end

  # What Devise leaves when SUPER_ADMIN_OTP_ENABLED is "disabled": a sign in
  # right after the reset, by Devise's own controller, which says nothing of how.
  context 'without OTP, after a password reset' do
    let(:super_admin) { create(:super_admin) }
    let(:new_password) { '{An0ther-$3cure-p4ssWord-for-SA}' }

    before { allow(SuperAdmin).to receive(:sign_in_after_reset_password).and_return(true) }

    it 'signs them in by password' do
      put super_admin_password_path, params: {
        super_admin: { reset_password_token: super_admin.send_reset_password_instructions, password: new_password, password_confirmation: new_password },
      }

      expect(response).to have_http_status(:redirect)
      expect(UserSession.where(sessionable: super_admin).sole.login_method).to eq('password')
    end
  end
end
