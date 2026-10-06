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
end
