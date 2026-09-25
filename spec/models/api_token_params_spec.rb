# frozen_string_literal: true

describe APITokenParams do
  let(:admin) { administrateurs.default }
  let(:token) { APIToken.generate(admin).first }

  describe '.from_token' do
    subject(:api_token_params) { described_class.from_token(token) }

    context 'with a full-access, read-write token with custom networks' do
      before do
        token.update!(
          name: 'Mon jeton',
          write_access: true,
          allowed_procedure_ids: nil,
          authorized_networks: [IPAddr.new('192.168.1.0/24'), IPAddr.new('10.0.0.0/8')]
        )
      end

      it 'derives the correct form fields' do
        expect(api_token_params.name).to eq('Mon jeton')
        expect(api_token_params.to_h).to include(
          target: 'all',
          access: 'read_write',
          networkFiltering: 'customNetworks',
          networks: '192.168.1.0/24 10.0.0.0/8'
        )
      end
    end

    context 'with a read-only token restricted to specific procedures' do
      let(:procedure) { create(:procedure, administrateur: admin) }

      before do
        token.update!(
          write_access: false,
          allowed_procedure_ids: [procedure.id],
          authorized_networks: []
        )
      end

      it 'derives the correct form fields' do
        expect(api_token_params.to_h).to include(
          target: 'custom',
          targets: [procedure.id],
          access: 'read',
          networkFiltering: 'autoAssign'
        )
        expect(api_token_params.to_h).not_to have_key(:networks)
      end
    end
  end
end
