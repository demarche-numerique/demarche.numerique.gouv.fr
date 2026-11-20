# frozen_string_literal: true

describe APITokenForm do
  let(:admin) { administrateurs.default }
  let(:token) { APIToken.generate(admin).first }

  describe 'validations' do
    subject(:form) do
      params = ActionController::Parameters.new(name: 'Test', access: 'read', target: 'all', lifetime: 'oneWeek', **attributes)
      described_class.new(params, administrateur: admin)
    end

    let(:procedure) { procedures.individual }

    before do
      stub_const('APIToken::MAX_LIFETIME', 365.days)
      form.validate
    end

    context 'with an owned procedure, custom networks and a custom lifetime' do
      let(:attributes) do
        {
          target: 'custom',
          targets: [procedure.id.to_s],
          networkFiltering: 'customNetworks',
          networks: '192.168.1.0/24 2001:41d0:304:400::52f/128',
          lifetime: 'custom',
          customLifetime: 3.months.from_now.to_date.iso8601,
        }
      end

      it { expect(form.errors).to be_empty }
    end

    context 'with a procedure the administrateur does not administer' do
      let(:admin) { administrateurs.blank }
      let(:attributes) { { target: 'custom', targets: [procedure.id.to_s] } }

      it { expect(form.errors).to be_of_kind(:allowed_procedure_ids, :blank) }
    end

    context 'with an invalid network' do
      let(:attributes) { { networkFiltering: 'customNetworks', networks: '192.168.1.0/24 bad' } }

      it { expect(form.errors).to be_of_kind(:networks, :invalid) }
    end

    context 'with an infinite lifetime' do
      let(:attributes) { { lifetime: 'infinite' } }

      it { expect(form.errors).to be_of_kind(:expires_at, :blank) }
    end

    context 'with an unparsable custom lifetime' do
      let(:attributes) { { lifetime: 'custom', customLifetime: 'not a date' } }

      it { expect(form.errors).to be_of_kind(:expires_at, :blank) }
    end

    context 'with a custom lifetime in the past' do
      let(:attributes) { { lifetime: 'custom', customLifetime: Date.yesterday.iso8601 } }

      it { expect(form.errors).to be_of_kind(:expires_at, :greater_than_or_equal_to) }
    end

    context 'with a custom lifetime beyond the cap' do
      let(:attributes) { { lifetime: 'custom', customLifetime: (APIToken.max_expires_at + 1.day).iso8601 } }

      it { expect(form.errors).to be_of_kind(:expires_at, :less_than_or_equal_to) }
    end
  end

  describe '.from_token' do
    subject(:form) { described_class.from_token(token) }

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
        expect(form.name).to eq('Mon jeton')
        expect(form.to_h).to include(
          target: 'all',
          access: 'read_write',
          networkFiltering: 'customNetworks',
          networks: '192.168.1.0/24 10.0.0.0/8'
        )
      end
    end

    context 'with a read-only token restricted to specific procedures' do
      let(:procedure) { procedures.individual }

      before do
        token.update!(
          write_access: false,
          allowed_procedure_ids: [procedure.id],
          authorized_networks: []
        )
      end

      it 'derives the correct form fields' do
        expect(form.to_h).to include(
          target: 'custom',
          targets: [procedure.id],
          access: 'read',
          networkFiltering: 'autoAssign'
        )
        expect(form.to_h).not_to have_key(:networks)
      end
    end
  end
end
