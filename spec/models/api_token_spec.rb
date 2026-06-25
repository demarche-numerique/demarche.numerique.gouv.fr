# frozen_string_literal: true

describe APIToken, type: :model do
  let(:administrateur) { administrateurs(:default_admin) }

  describe '#generate' do
    let(:api_token_and_packed_token) { APIToken.generate(administrateur) }
    let(:api_token) { api_token_and_packed_token.first }
    let(:packed_token) { api_token_and_packed_token.second }

    before { api_token_and_packed_token }

    it 'with a full access token' do
      expect(api_token.administrateur).to eq(administrateur)
      expect(api_token.prefix).to eq(packed_token.slice(0, 5))
      expect(api_token.version).to eq(3)
      expect(api_token.write_access?).to eq(true)
      expect(api_token.procedure_ids).to eq([])
      expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
      expect(api_token.full_access?).to be_truthy
    end

    context 'updated read_only' do
      before { api_token.update(write_access: false) }

      it do
        expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: false, api_token_id: api_token.id)
      end
    end

    context 'with a new added procedure' do
      let(:procedure) { create(:procedure, administrateurs: [administrateur]) }

      before do
        procedure
        api_token.reload
      end

      it do
        expect(api_token.full_access?).to be_truthy
        expect(api_token.procedure_ids).to eq([procedure.id])
        expect(api_token.procedures).to eq([procedure])
        expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [procedure.id], write_access: true, api_token_id: api_token.id)
      end

      context 'and another procedure, but access only to the first one' do
        let(:other_procedure) { create(:procedure, administrateurs: [administrateur]) }

        before do
          other_procedure
          api_token.update(allowed_procedure_ids: [procedure.id])
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to match_array([procedure.id])
          expect(api_token.targetable_procedures).to eq([other_procedure])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [procedure.id], write_access: true, api_token_id: api_token.id)
        end
      end

      context 'but acces to a wrong procedure_id' do
        let(:forbidden_procedure) { create(:procedure, :new_administrateur) }

        before do
          api_token.update(allowed_procedure_ids: [forbidden_procedure.id])
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to eq([])
          expect(api_token.targetable_procedures).to eq([procedure])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end

      context 'update with destroyed procedure_id' do
        let(:procedure) { create(:procedure, administrateurs: [administrateur]) }

        before do
          api_token.update(allowed_procedure_ids: [procedure.id])
          procedure.destroy
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to eq([])
          expect(api_token.targetable_procedures).to eq([])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end

      context 'update with detached procedure_id' do
        let(:procedure) { create(:procedure, administrateurs: [administrateur]) }
        let(:other_procedure) { create(:procedure, administrateurs: [administrateur]) }

        before do
          api_token.update(allowed_procedure_ids: [procedure.id])
          other_procedure
          administrateur.procedures.delete(procedure)
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to eq([])
          expect(api_token.targetable_procedures).to eq([other_procedure])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end
    end
  end

  describe '#authenticate' do
    let(:api_token_and_packed_token) { APIToken.generate(administrateur) }
    let(:api_token) { api_token_and_packed_token.first }
    let(:packed_token) { api_token_and_packed_token.second }
    let(:bearer_token) { packed_token }

    subject { APIToken.authenticate(bearer_token) }

    context 'with the legit packed token' do
      it { is_expected.to eq(api_token) }
    end

    context 'with destroyed token' do
      before { api_token.destroy }

      it { is_expected.to be_nil }
    end

    context 'with destroyed administrateur' do
      before { api_token.administrateur.destroy }

      it { is_expected.to be_nil }
    end

    context "with a bearer token with the wrong plain_token" do
      let(:bearer_token) do
        APIToken::BearerToken.new(api_token.id, 'wrong').to_string
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#store_new_ip' do
    let(:api_token) { APIToken.generate(administrateur).first }
    let(:ip) { '192.168.0.1' }

    subject do
      api_token.store_new_ip(ip)
      api_token.stored_ips
    end

    context 'when none ip is stored' do
      it { is_expected.to eq([IPAddr.new(ip)]) }
    end

    context 'when the ip is already stored' do
      before { api_token.update!(stored_ips: [ip]) }

      it { is_expected.to eq([IPAddr.new(ip)]) }
    end
  end

  describe '#forbidden_network?' do
    let(:api_token_and_packed_token) { APIToken.generate(administrateur) }
    let(:api_token) { api_token_and_packed_token.first }
    let(:authorized_networks) { [] }

    before { api_token.update!(authorized_networks: authorized_networks) }

    subject { api_token.forbidden_network?(ip) }

    context 'when no authorized networks are defined' do
      let(:ip) { '192.168.1.1' }

      it { is_expected.to be_falsey }
    end

    context 'when a single authorized network is defined' do
      let(:authorized_networks) { [IPAddr.new('192.168.1.0/24')] }

      context 'and the request comes from it' do
        let(:ip) { '192.168.1.1' }

        it { is_expected.to be_falsey }
      end

      context 'and the request does not come from it' do
        let(:ip) { '192.168.2.1' }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#assign_first_ip!' do
    let(:api_token) { APIToken.generate(administrateur).first }

    context 'when requires_ip_filtering is true and no networks defined' do
      before { api_token.update!(requires_ip_filtering: true) }

      it 'assigns the IP as authorized network' do
        api_token.assign_first_ip!('192.168.1.1')
        expect(api_token.reload.authorized_networks).to eq([IPAddr.new('192.168.1.1')])
      end

      it 'works with IPv6' do
        api_token.assign_first_ip!('2001:41d0:304:400::52f')
        expect(api_token.reload.authorized_networks).to eq([IPAddr.new('2001:41d0:304:400::52f')])
      end
    end

    context 'when requires_ip_filtering is false' do
      before { api_token.update!(requires_ip_filtering: false) }

      it 'does nothing' do
        api_token.assign_first_ip!('192.168.1.1')
        expect(api_token.reload.authorized_networks).to be_empty
      end
    end

    context 'when authorized_networks already set' do
      before do
        api_token.update!(requires_ip_filtering: true, authorized_networks: [IPAddr.new('10.0.0.1')])
      end

      it 'does not overwrite' do
        api_token.assign_first_ip!('192.168.1.1')
        expect(api_token.reload.authorized_networks).to eq([IPAddr.new('10.0.0.1')])
      end
    end
  end

  describe '#pending_auto_ip?' do
    let(:api_token) { APIToken.generate(administrateur).first }

    it 'returns true when requires_ip_filtering and no networks' do
      api_token.update!(requires_ip_filtering: true, authorized_networks: [])
      expect(api_token.pending_auto_ip?).to be true
    end

    it 'returns false when requires_ip_filtering is false' do
      api_token.update!(requires_ip_filtering: false, authorized_networks: [])
      expect(api_token.pending_auto_ip?).to be false
    end

    it 'returns false when networks are present' do
      api_token.update!(requires_ip_filtering: true, authorized_networks: [IPAddr.new('10.0.0.1')])
      expect(api_token.pending_auto_ip?).to be false
    end
  end

  describe '#expiring_within' do
    let(:api_token) { APIToken.generate(administrateur).first }

    subject { APIToken.expiring_within(7.days) }

    context 'when the token is not expiring' do
      it { is_expected.to be_empty }
    end

    context 'when the token is expiring in the range' do
      before { api_token.update!(expires_at: 1.day.from_now) }

      it { is_expected.to eq([api_token]) }
    end

    context 'when the token is not expiring in the range' do
      before { api_token.update!(expires_at: 8.days.from_now) }

      it { is_expected.to be_empty }
    end

    context 'when the token is expired' do
      before { api_token.update!(expires_at: 1.day.ago) }

      it { is_expected.to be_empty }
    end
  end

  describe '#without_any_expiration_notice_sent_within' do
    let(:api_token) { APIToken.generate(administrateur).first }
    let(:today) { Date.new(2018, 01, 01) }
    let(:expires_at) { Date.new(2018, 06, 01) }

    subject { APIToken.without_any_expiration_notice_sent_within(7.days) }

    before do
      travel_to(today)
      api_token.update!(created_at: today, expires_at:)
    end

    context 'when the token has not been notified' do
      it { is_expected.to eq([api_token]) }
    end

    context 'when the token has been notified' do
      before do
        api_token.expiration_notices_sent_at << expires_at - 7.days
        api_token.save!
      end

      it { is_expected.to be_empty }
    end

    context 'when the token has been notified outside the window' do
      before do
        api_token.expiration_notices_sent_at << expires_at - 8.days
        api_token.save!
      end

      it { is_expected.to eq([api_token]) }
    end
  end

  describe '#with_expiration_notice_to_send_for' do
    let(:api_token) { APIToken.generate(administrateur).first }
    let(:duration) { 7.days }

    subject do
      APIToken.with_expiration_notice_to_send_for(duration)
    end

    context 'when the token is expiring in the range' do
      before { api_token.update!(expires_at: 1.day.from_now, created_at:) }

      let(:created_at) { 1.year.ago }

      it do
        is_expected.to eq([api_token])
      end

      context 'when the token has been created within the time frame' do
        let(:created_at) { 2.days.ago }

        it { is_expected.to be_empty }
      end

      context 'when the token has already been notified' do
        before do
          api_token.expiration_notices_sent_at << 1.day.ago
          api_token.save!
        end

        it { is_expected.to be_empty }
      end

      context 'when the token has already been notified for another window' do
        before do
          api_token.expiration_notices_sent_at << 1.month.ago
          api_token.save!
        end

        it do
          is_expected.to eq([api_token])
        end
      end
    end
  end
end
