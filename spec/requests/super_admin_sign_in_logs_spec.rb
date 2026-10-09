# frozen_string_literal: true

describe 'super admin sign in logs', type: :request do
  let(:super_admin) { create(:super_admin, :with_otp) }
  let(:logs) { [] }

  around do |example|
    ActiveSupport::Notifications.subscribed(-> (*, payload) { logs << payload[:to_log] }, 'process_action.action_controller') do
      example.run
    end
  end

  it 'identifies the super admin who signs in' do
    post_super_admin_session(super_admin)

    expect(logs.sole).to include(super_admin_id: super_admin.id, user_roles: 'SuperAdmin')
  end

  it 'identifies the account targeted by a failed attempt' do
    post super_admin_session_path, params: { super_admin: { email: super_admin.email, password: 'wrong password', otp_attempt: current_otp_for(super_admin) } }

    expect(logs.pluck(:super_admin_id, :failed_attempt)).to eq([[super_admin.id, 'invalid'], [nil, nil]])
  end

  it 'tells when the targeted account is locked' do
    super_admin.lock_access!

    post super_admin_session_path, params: { super_admin: { email: super_admin.email, password: super_admin.password, otp_attempt: current_otp_for(super_admin) } }

    expect(logs.first).to include(super_admin_id: super_admin.id, failed_attempt: 'locked')
  end
end
