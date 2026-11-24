# frozen_string_literal: true

describe APIToken, type: :model do
  # Tokens expose all the admin's procedures: use the seeded blank
  # administrateur, who is guaranteed to own nothing.
  let(:administrateur) { administrateurs.blank }

  describe 'expires_at validations' do
    # A new record validates in the :create context, which is where the
    # expiration rules live.
    subject(:api_token) { APIToken.new(administrateur:, expires_at:) }

    context 'when expires_at is missing' do
      let(:expires_at) { nil }

      it 'is rejected as blank' do
        expect(api_token).to be_invalid
        expect(api_token.errors).to be_of_kind(:expires_at, :blank)
      end
    end

    context 'when expires_at is in the past' do
      let(:expires_at) { 1.day.ago.to_date }

      it 'is rejected as too soon' do
        expect(api_token).to be_invalid
        expect(api_token.errors).to be_of_kind(:expires_at, :greater_than_or_equal_to)
      end
    end

    context 'when expires_at is today' do
      let(:expires_at) { Date.current }

      it 'is rejected as too soon' do
        expect(api_token).to be_invalid
        expect(api_token.errors).to be_of_kind(:expires_at, :greater_than_or_equal_to)
      end
    end

    context 'when expires_at is tomorrow' do
      let(:expires_at) { Date.tomorrow }

      it { is_expected.to be_valid }
    end

    context 'when expires_at is exactly the configured cap' do
      let(:expires_at) { APIToken.max_expires_at }

      it { is_expected.to be_valid }
    end

    context 'when expires_at is beyond the configured cap' do
      let(:expires_at) { APIToken.max_expires_at + 1.day }

      it 'is rejected as too late' do
        expect(api_token).to be_invalid
        expect(api_token.errors).to be_of_kind(:expires_at, :less_than_or_equal_to)
      end
    end

    context 'when the cap is lowered by configuration' do
      before { stub_const('APIToken::MAX_LIFETIME', 90.days) }

      let(:expires_at) { 91.days.from_now.to_date }

      it 'is rejected as too late' do
        expect(api_token).to be_invalid
        expect(api_token.errors).to be_of_kind(:expires_at, :less_than_or_equal_to)
      end
    end

    describe '.generate' do
      it 'refuses to create a token without an expiration date' do
        expect {
          expect { APIToken.generate(administrateur, expires_at: nil) }
            .to raise_error(ActiveRecord::RecordInvalid) { |error|
              expect(error.record.errors).to be_of_kind(:expires_at, :blank)
            }
        }.not_to change { administrateur.api_tokens.count }
      end
    end

    # The existing stock of eternal tokens is out of scope for now: it must stay
    # valid and editable, so the validation only runs on create.
    context 'with a legacy eternal token' do
      let(:expires_at) { 1.week.from_now.to_date }

      it 'stays editable' do
        persisted = APIToken.generate(administrateur, expires_at:).first
        persisted.update_column(:expires_at, nil)

        expect(persisted.reload.expires_at).to be_nil
        expect { persisted.update!(name: 'renamed') }.not_to raise_error
      end
    end
  end

  describe '.selectable_lifetimes' do
    it 'exposes every preset under the default cap' do
      stub_const('APIToken::MAX_LIFETIME', 365.days)

      expect(APIToken.selectable_lifetimes.keys).to eq([:oneWeek, :oneMonth, :sixMonths, :oneYear])
    end

    it 'drops the presets longer than the configured cap' do
      stub_const('APIToken::MAX_LIFETIME', 90.days)

      expect(APIToken.selectable_lifetimes.keys).to eq([:oneWeek, :oneMonth])
    end
  end

  # Every token is now created with an expiration date, so check the existing
  # expiration notices actually reach each of the lifetimes we offer.
  describe 'expiration notices coverage' do
    # Pin the cap so every preset stays creatable whatever the configuration.
    before { stub_const('APIToken::MAX_LIFETIME', 365.days) }

    # created_at is a timestamp while expires_at is a date: generate at noon so the
    # lifetime comes out the same whatever the time of day the suite runs
    let(:api_token) do
      travel_to(Time.zone.local(2026, 9, 15, 12)) do
        APIToken.generate(administrateur, expires_at: duration.from_now.to_date).first
      end
    end

    def notified_windows(token)
      [1.month, 1.week, 1.day].filter do |window|
        travel_to(token.expires_at - window) do
          APIToken.with_expiration_notice_to_send_for(window).exists?(id: token.id)
        end
      end
    end

    context 'with the shortest lifetime' do
      let(:duration) { APIToken::LIFETIMES[:oneWeek] }

      it 'only warns the day before' do
        expect(notified_windows(api_token)).to eq([1.day])
      end
    end

    context 'with the longest lifetime' do
      let(:duration) { APIToken::LIFETIMES[:oneYear] }

      it 'warns a month, a week and a day before' do
        expect(notified_windows(api_token)).to eq([1.month, 1.week, 1.day])
      end
    end

    it 'always warns at least the day before' do
      APIToken.selectable_lifetimes.each_value do |lifetime|
        token = APIToken.generate(administrateur, expires_at: lifetime.from_now.to_date).first

        travel_to(token.expires_at - 1.day) do
          expect(APIToken.with_expiration_notice_to_send_for(1.day)).to include(token)
        end
      end
    end
  end

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
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end

      context 'with a listed procedure put in the bin then restored' do
        before do
          api_token.update!(allowed_procedure_ids: [procedure.id])
          procedure.discard!
          api_token.store_new_ip('203.0.113.7')
          procedure.undiscard!
        end

        it { expect(api_token.reload.procedure_ids).to eq([procedure.id]) }
      end

      context 'when its owner is removed from a listed procedure' do
        let(:co_admin) { administrateurs.default }
        let(:procedure) { procedures.individual }
        let(:other_procedure) { procedures.brouillon }
        let(:co_admin_token) { APIToken.generate(co_admin).first }

        before do
          [procedure, other_procedure].each { it.administrateurs << administrateur }
          api_token.update!(allowed_procedure_ids: [procedure.id, other_procedure.id])
          co_admin_token.update!(allowed_procedure_ids: [procedure.id])
          procedure.administrateurs.delete(administrateur)
        end

        it 'drops the procedure from its own tokens only' do
          expect(api_token.reload.allowed_procedure_ids).to eq([other_procedure.id])
          expect(co_admin_token.reload.allowed_procedure_ids).to eq([procedure.id])
        end
      end
    end
  end

  describe '.authenticable' do
    let(:api_token) { APIToken.generate(administrateur).first }

    subject { APIToken.authenticable }

    context 'with a version 3 token' do
      it { is_expected.to include(api_token) }
    end

    [1, 2].each do |version|
      context "with a version #{version} token" do
        before { api_token.update_column(:version, version) }

        it { is_expected.not_to include(api_token) }
      end
    end

    # A newer format would authenticate; pinning the scope to 3 would reject it
    # everywhere at once, silently.
    context 'with a token from a future version' do
      before { api_token.update_column(:version, 4) }

      it { is_expected.to include(api_token) }
    end
  end

  describe '.reading' do
    let(:procedure) { procedures.individual }
    let(:other_procedure) { procedures.brouillon }
    let(:support) { create(:administrateur) }

    let!(:full_access) { APIToken.generate(administrateur).first }
    let!(:listed) { APIToken.generate(administrateur, allowed_procedure_ids: [procedure.id]).first }
    let!(:elsewhere) { APIToken.generate(administrateur, allowed_procedure_ids: [other_procedure.id]).first }
    let!(:expired) { APIToken.generate(administrateur).first.tap { it.update_column(:expires_at, 1.day.ago.to_date) } }
    let!(:support_token) { APIToken.generate(support).first }

    before do
      [procedure, other_procedure].each { it.administrateurs << administrateur }
      AdministrateursProcedure.create!(procedure:, administrateur: support, manager: true)
    end

    it 'lists the live tokens of its administrateurs that read it, support left out' do
      expect(APIToken.reading(procedure)).to contain_exactly(full_access, listed)
    end
  end

  describe '#pin_procedures' do
    let(:api_token) { APIToken.generate(administrateur, allowed_procedure_ids: [1, 2, 3]).first }

    it 'leaves follows_clones of a list token as it was' do
      api_token.pin_procedures([1, 2])
      expect(api_token).to have_attributes(allowed_procedure_ids: [1, 2], follows_clones: false)
    end
  end

  describe '.visible_to' do
    let(:reader) { administrateurs.blank }
    let(:owner) { administrateurs.default }
    let(:shared) { procedures.individual }
    let(:owners_only) { procedures.brouillon }
    let(:support) { create(:administrateur) }
    let(:reader_is_support) { false }

    let!(:full_access) { APIToken.generate(owner).first }
    let!(:listed) { APIToken.generate(owner, allowed_procedure_ids: [shared.id]).first }
    let!(:elsewhere) { APIToken.generate(owner, allowed_procedure_ids: [owners_only.id]).first }
    let!(:expired) { APIToken.generate(owner).first.tap { it.update_column(:expires_at, 1.day.ago.to_date) } }
    let!(:legacy) { APIToken.generate(owner).first.tap { it.update_column(:version, 2) } }
    let!(:own) { APIToken.generate(reader).first }
    let!(:support_token) { APIToken.generate(support).first }

    before do
      AdministrateursProcedure.create!(procedure: shared, administrateur: reader, manager: reader_is_support)
      AdministrateursProcedure.create!(procedure: shared, administrateur: support, manager: true)
    end

    it 'lists the live tokens of co-administrateurs reading a shared procedure, support left out' do
      expect(APIToken.visible_to(reader)).to contain_exactly(full_access, listed)
    end

    context 'when the reader is attached as support' do
      let(:reader_is_support) { true }

      it { expect(APIToken.visible_to(reader)).to be_empty }
    end

    context 'when the shared procedure is in the bin' do
      before { shared.discard! }

      it { expect(APIToken.visible_to(reader)).to be_empty }
    end

    context 'when the owner left the shared procedure without its list forgetting it' do
      before { AdministrateursProcedure.where(procedure: shared, administrateur: owner).delete_all }

      it { expect(APIToken.visible_to(reader)).to be_empty }
    end
  end

  describe '.duplicable_by' do
    let(:reader) { administrateurs.blank }
    let(:owner) { administrateurs.default }
    let!(:listed) { APIToken.generate(owner, allowed_procedure_ids: [procedures.individual.id]).first }
    let!(:elsewhere) { APIToken.generate(owner, allowed_procedure_ids: [procedures.brouillon.id]).first }
    let!(:own_expired) { APIToken.generate(reader).first.tap { it.update_column(:expires_at, 1.day.ago.to_date) } }

    before { procedures.individual.administrateurs << reader }

    it 'adds the own tokens of the administrateur, expired ones included, to the visible ones' do
      expect(APIToken.duplicable_by(reader)).to contain_exactly(listed, own_expired)
    end
  end

  describe '#expiration_co_recipients' do
    let(:owner) { administrateurs.default }
    let(:procedure) { procedures.individual }
    let(:stranger) { create(:administrateur) }
    let(:supported_procedure) { create(:procedure, administrateurs: [stranger]) }
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: [procedure.id, supported_procedure.id]).first }
    let(:co_admins) { create_list(:administrateur, 6) }
    let(:token_holder) { co_admins.first }
    let(:support) { create(:administrateur) }

    before do
      co_admins.each_with_index do |co_admin, i|
        procedure.administrateurs << co_admin
        co_admin.user.update_column(:last_sign_in_at, i.days.ago)
      end
      token_holder.user.update_column(:last_sign_in_at, 1.year.ago)
      APIToken.generate(token_holder, allowed_procedure_ids: [procedure.id])

      APIToken.generate(co_admins.last).first.update_column(:expires_at, 1.day.ago.to_date)
      APIToken.generate(co_admins.last).first.update_column(:version, 2)
      APIToken.generate(co_admins.last, allowed_procedure_ids: [procedures.brouillon.id])

      AdministrateursProcedure.create!(procedure:, administrateur: support, manager: true)
      support.user.update_column(:last_sign_in_at, Time.current)

      AdministrateursProcedure.create!(procedure: supported_procedure, administrateur: owner, manager: true)
      stranger.user.update_column(:last_sign_in_at, Time.current)
    end

    it 'picks five co-administrateurs outside support, holders of a valid token on these procedures first, then the most recently signed in' do
      expect(api_token.expiration_co_recipients).to eq([token_holder, *co_admins[1..4]])
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

      context 'which matches the bcrypt hash' do
        before { api_token.update_column(:encrypted_token, BCrypt::Password.create('wrong')) }

        it { is_expected.to be_nil }
      end
    end

    context 'with a bearer token without plain_token' do
      let(:bearer_token) { Base64.urlsafe_encode64(api_token.id) }

      it { is_expected.to be_nil }
    end

    context 'with a token created before token_digest' do
      before { api_token.update_column(:token_digest, nil) }

      it 'authenticates with bcrypt once, then with the digest' do
        expect(subject).to eq(api_token)

        api_token.update_column(:encrypted_token, BCrypt::Password.create('wrong'))
        expect(APIToken.authenticate(bearer_token)).to eq(api_token)
      end

      context "with the wrong plain_token" do
        let(:bearer_token) do
          APIToken::BearerToken.new(api_token.id, 'wrong').to_string
        end

        it 'does not store a digest' do
          expect(subject).to be_nil
          expect(api_token.reload.token_digest).to be_nil
        end
      end
    end
  end

  describe '.parse_networks' do
    it 'rejects an IPv6 zone and a stacked mask' do
      networks = APIToken.parse_networks('fe80::1%eth0 10.0.0.1/255.255.255.0/1 10.0.0.0/255.0.0.0')

      expect(networks.map { it && "#{it}/#{it.prefix}" }).to eq([nil, nil, '10.0.0.0/8'])
    end
  end

  describe '#authorized_networks_for_ui' do
    it 'writes IPv6 networks in their compressed form' do
      api_token = APIToken.new(authorized_networks: [IPAddr.new('192.168.1.0/24'), IPAddr.new('2a01:e0a:1f2:4b30::/64')])

      expect(api_token.authorized_networks_for_ui).to eq('192.168.1.0/24, 2a01:e0a:1f2:4b30::/64')
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

  describe '#expiring_soon?' do
    let(:api_token) { APIToken.generate(administrateur).first }

    subject { api_token.expiring_soon? }

    context 'when expiring in 2 weeks' do
      before { api_token.update!(expires_at: 2.weeks.from_now.to_date) }

      it { is_expected.to be true }
    end

    context 'when expiring today' do
      before { api_token.update_column(:expires_at, Date.current) }

      it { is_expected.to be true }
    end

    context 'when expiring in exactly 1 month' do
      before { api_token.update!(expires_at: 1.month.from_now.to_date) }

      it { is_expected.to be true }
    end

    context 'when expiring in 2 months' do
      before { api_token.update!(expires_at: 2.months.from_now.to_date) }

      it { is_expected.to be false }
    end

    context 'when already expired' do
      before { api_token.update_column(:expires_at, 1.day.ago.to_date) }

      it { is_expected.to be false }
    end

    context 'when eternal (no expiration date)' do
      before { api_token.update_column(:expires_at, nil) }

      it { is_expected.to be false }
    end
  end

  describe '#expiring_within' do
    let(:api_token) { APIToken.generate(administrateur).first }

    subject { APIToken.expiring_within(7.days) }

    # the scope reads the system date while expires_at is cast in the Paris zone:
    # pin the clock away from midnight, where the two dates differ
    before { travel_to(Time.zone.local(2026, 9, 15, 12)) }

    context 'when the token is not expiring' do
      before { api_token.update_column(:expires_at, nil) }

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

      # Version 1 and 2 tokens cannot authenticate any more, so announcing their
      # expiration would be telling an administrateur that something is about to
      # break when it broke years ago. They only reach this scope once the
      # backfill gives them a date.
      [1, 2].each do |version|
        context "when the token is a version #{version}" do
          before { api_token.update_column(:version, version) }

          it { is_expected.to be_empty }
        end
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
