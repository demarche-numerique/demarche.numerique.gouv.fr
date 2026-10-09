# frozen_string_literal: true

describe 'MaintenanceTasks request logs', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:payloads) { [] }

  before { login_as super_admin, scope: :super_admin }

  around do |example|
    ActiveSupport::Notifications.subscribed(-> (*, payload) { payloads << payload }, 'process_action.action_controller') do
      example.run
    end
  end

  it 'identifies the super admin and their IP' do
    get '/manager/maintenance_tasks', headers: { 'REMOTE_ADDR' => '203.0.113.7' }

    expect(payloads.sole[:to_log]).to eq(super_admin_id: super_admin.id, client_ip: '203.0.113.7')
  end
end
