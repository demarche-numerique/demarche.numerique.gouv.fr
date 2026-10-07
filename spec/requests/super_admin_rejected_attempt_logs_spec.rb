# frozen_string_literal: true

describe 'super admin rejected attempt logs', type: :request do
  let(:super_admin) { create(:super_admin, :with_otp) }
  let(:logs) { [] }

  # :fetch, a session opened by an earlier request: on any other event, Devise
  # resets failed_attempts and the lockout below never comes.
  before { login_as super_admin, scope: :super_admin, event: :fetch }

  around do |example|
    ActiveSupport::Notifications.subscribed(-> (*, payload) { logs << payload[:to_log] }, 'process_action.action_controller') do
      example.run
    end
  end

  it 'marks a rejected OTP re-enrolment' do
    put enable_super_admin_otp_path, params: { current_password: 'wrong password', otp_attempt: current_otp_for(super_admin) }

    expect(logs.sole).to include(super_admin_id: super_admin.id, failed_attempt: 'invalid')
  end

  it 'identifies the super admin whose step-up OTP locks the account, though it signs them out' do
    super_admin.update!(failed_attempts: SuperAdmin.maximum_attempts - 1)

    delete "/manager/users/#{users.usager.id}/delete", params: { otp_attempt: current_otp_for(super_admin) }

    expect(logs.sole).to include(super_admin_id: super_admin.id, failed_attempt: 'locked')
  end
end
