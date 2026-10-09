# frozen_string_literal: true

describe Manager::ApplicationController, type: :controller do
  describe 'append_info_to_payload' do
    let(:current_user) { users.usager }
    let(:current_super_admin) { create(:super_admin) }
    let(:payload) { {} }

    before do
      allow(@controller).to receive(:media_type).and_return('text/plain')
      allow(@controller).to receive(:current_user).and_return(current_user)
      allow(@controller).to receive(:current_super_admin).and_return(current_super_admin)
      @controller.send(:append_info_to_payload, payload)
    end

    it do
      [:db_runtime, :view_runtime, :variant, :rendered_format].each do |key|
        payload.delete(key)
      end
      expect(payload[:to_log]).to eq({
        user_agent: 'Rails Testing',
        user_id: current_user.id,
        user_email: current_user.email,
        super_admin_id: current_super_admin.id,
        client_ip: '0.0.0.0',
      })
    end
  end
end
