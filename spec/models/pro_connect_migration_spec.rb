# frozen_string_literal: true

describe ProConnectMigration do
  let(:account) { administrateurs.default.user }
  let(:migration) { ProConnectMigration.create!(user: account, source_email: account.email) }
  let(:user_info) { { 'sub' => 'sub', 'email' => email, 'given_name' => 'Camille', 'usual_name' => 'Dupont' } }

  describe '#login_hint' do
    it 'suggests an address that looks nominative' do
      expect(ProConnectMigration.new(source_email: 'cedric.martin@exemple.gouv.fr').login_hint).to eq('cedric.martin@exemple.gouv.fr')
    end

    it 'does not suggest what looks like a functional mailbox' do
      expect(ProConnectMigration.new(source_email: 'service_rh@exemple.gouv.fr').login_hint).to be_nil
      expect(ProConnectMigration.new(source_email: 'ddt-sg@exemple.gouv.fr').login_hint).to be_nil
    end

    it 'does not suggest the address to a co-holder' do
      expect(ProConnectMigration.new(source_email: 'cedric.martin@exemple.gouv.fr', parent_id: 1).login_hint).to be_nil
    end
  end

  describe '#identify!' do
    subject { migration.identify!(auth: ProConnectService::Authentication.new(user_info:, id_token: 'id_token', amr: ['mfa'], acr: nil)) }

    context 'with the address of the account' do
      let(:email) { account.email }

      it { subject; expect(migration).to be_same_email }
    end

    context 'from another domain' do
      let(:email) { 'camille.dupont@ailleurs.fr' }

      it { subject; expect(migration).to be_domain_mismatch }
    end

    context 'with an address that already has an account, even an empty one' do
      let(:email) { users.usager.email }

      it { subject; expect(migration).to be_existing_account }
    end

    context 'with a free address of the same domain' do
      let(:email) { 'camille.dupont@exemple.fr' }

      it { subject; expect(migration).to be_awaiting_code }
    end

    context 'for a co-holder' do
      let(:origin) { ProConnectMigration.create!(user: account, source_email: 'contact@exemple.fr', state: :renamed, shared: true) }
      let(:migration) { ProConnectMigration.create!(user: account, source_email: 'contact@exemple.fr', parent: origin) }

      context 'with an address that already has an account' do
        let(:email) { users.usager.email }

        it { subject; expect(migration).to be_awaiting_code }
      end

      context 'with the old address itself' do
        let(:email) { 'contact@exemple.fr' }

        it { subject; expect(migration).to be_awaiting_code }
      end

      context 'from another domain' do
        let(:email) { 'camille.dupont@ailleurs.fr' }

        it { subject; expect(migration).to be_domain_mismatch }
      end
    end
  end

  describe '#verify_code' do
    let(:email) { 'camille.dupont@exemple.fr' }
    let(:code) { '123456' }

    before do
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456)
      migration.identify!(auth: ProConnectService::Authentication.new(user_info:, id_token: 'id_token', amr: ['mfa'], acr: nil))
      migration.send_code!(Browser.new(''))
    end

    it 'accepts the code, spaces included' do
      expect(migration.verify_code('123 456')).to be true
    end

    it 'refuses a wrong code and counts the attempt' do
      expect(migration.verify_code('000000')).to be false
      expect(migration.reload.code_attempts).to eq(1)
    end

    it 'refuses even the right code after five attempts' do
      migration.update!(code_attempts: 5)

      expect(migration.verify_code(code)).to be false
    end

    it 'refuses even the right code after ten minutes' do
      migration.update!(code_sent_at: 11.minutes.ago)

      expect(migration.verify_code(code)).to be false
    end
  end

  describe '#resend_code!' do
    let(:email) { 'camille.dupont@exemple.fr' }

    before do
      migration.identify!(auth: ProConnectService::Authentication.new(user_info:, id_token: 'id_token', amr: ['mfa'], acr: nil))
      migration.send_code!(Browser.new(''))
      migration.update_columns(code_sent_at: 2.minutes.ago)
    end

    it 'sends one code for two requests in flight' do
      in_flight = ProConnectMigration.find(migration.id)

      expect(migration.resend_code!(Browser.new(''))).to be true
      expect(in_flight.resend_code!(Browser.new(''))).to be false
    end
  end

  describe '#rename!' do
    let(:administrateur) { administrateurs.default }
    let!(:migration) do
      ProConnectMigration.create!(user: account, source_email: account.email, state: :awaiting_code, pro_connect_email: 'camille.dupont@exemple.fr')
    end
    let(:auth) { ProConnectService::Authentication.new(user_info: { 'sub' => 'sub', 'email' => 'camille.dupont@exemple.fr' }, id_token: 'id_token', amr: ['mfa'], acr: nil) }
    let(:procedure) { procedures.individual }
    let(:support_procedure) { create(:procedure, administrateur: administrateurs.blank) }
    let(:groupe) { procedure.defaut_groupe_instructeur }

    before do
      AdministrateursProcedure.create!(administrateur:, procedure: support_procedure, manager: true)
      groupe.add(instructeurs.admin)
      instructeurs.admin.assign_to.create!(groupe_instructeur: support_procedure.defaut_groupe_instructeur, manager: true)
    end

    it 'moves the account to the ProConnect address, silently, keeping its password' do
      expect { migration.rename!(auth:, shared: false) }.not_to have_enqueued_mail

      account.reload
      expect(account.email).to eq('camille.dupont@exemple.fr')
      expect(account.valid_password?(users.default_password)).to be true
      expect(administrateur.reload.pro_connect_required_at).not_to be_nil
      expect(account.pro_connect_informations.pluck(:sub)).to eq(['sub'])
      expect(migration).to be_renamed
      expect(migration.shared).to be false
      expect(migration.procedure_ids).to include(procedure.id)
      expect(migration.procedure_ids).not_to include(support_procedure.id)
      expect(migration.groupe_instructeur_ids).to eq([groupe.id])
    end

    it 'drops the address change and the merge another holder left pending, and trusts the ProConnect address' do
      account.update_columns(unconfirmed_email: 'bob@exemple.fr', requested_merge_into_id: users.usager.id, email_verified_at: nil)

      migration.rename!(auth:, shared: true)

      account.reload
      expect(account.unconfirmed_email).to be_nil
      expect(account.requested_merge_into).to be_nil
      expect(account.email_verified_at).not_to be_nil
    end

    it 'gives up when the address was taken in the meantime' do
      create(:user, email: 'camille.dupont@exemple.fr')

      expect(migration.rename!(auth:, shared: true)).to be false
      expect(account.reload.email).to eq(migration.source_email)
    end

    it 'gives up when the account was renamed in the meantime' do
      account.update_column(:email, 'autre@exemple.fr')

      expect(migration.rename!(auth:, shared: true)).to be false
    end

    it 'gives up with the ProConnect identity of another address' do
      other = auth.with(user_info: { 'sub' => 'other', 'email' => 'dominique.martin@exemple.fr' })

      expect(migration.rename!(auth: other, shared: true)).to be false
      expect(account.reload.email).to eq(migration.source_email)
    end
  end

  describe '#grant!' do
    let(:auth) { ProConnectService::Authentication.new(user_info: { 'sub' => 'sub2', 'email' => email }, id_token: 'id_token', amr: ['mfa'], acr: nil) }
    let(:procedure) { procedures.individual }
    let(:discarded_procedure) { create(:procedure, administrateur: administrateurs.blank, hidden_at: Time.current) }
    let(:groupe) { procedure.defaut_groupe_instructeur }
    let(:other_groupe) { create(:groupe_instructeur, procedure:) }
    let(:origin) do
      ProConnectMigration.create!(
        user: account, source_email: 'contact@exemple.fr', state: :renamed, shared: true,
        procedure_ids: [procedure.id, discarded_procedure.id], groupe_instructeur_ids: [groupe.id, other_groupe.id]
      )
    end
    let(:migration) do
      ProConnectMigration.create!(
        user: account, source_email: 'contact@exemple.fr', parent: origin, state: :awaiting_code,
        pro_connect_email: email
      )
    end

    context 'with a new address' do
      let(:email) { 'dominique.martin@exemple.fr' }

      it 'creates an administrateur of the recorded procedures, trashed ones included, and an instructeur of the recorded groups' do
        migration.grant!(auth:)

        target = User.find_by!(email:)
        expect(target.administrateur.procedures.with_discarded).to contain_exactly(procedure, discarded_procedure)
        expect(target.administrateur.pro_connect_required_at).not_to be_nil
        expect(target.instructeur.groupe_instructeurs).to contain_exactly(groupe, other_groupe)
        expect(target.pro_connect_informations.pluck(:sub)).to eq(['sub2'])
        expect(migration).to have_attributes(state: 'granted', target_user: target)
      end
    end

    context 'with the ProConnect identity of another address' do
      let(:email) { 'dominique.martin@exemple.fr' }

      it 'gives up' do
        other = auth.with(user_info: { 'sub' => 'other', 'email' => 'claude.durand@exemple.fr' })

        expect(migration.grant!(auth: other)).to be false
        expect(User.exists?(email: email)).to be false
      end
    end

    context 'with an address that already has an account' do
      let(:email) { users.usager.email }

      it 'completes it' do
        migration.grant!(auth:)

        expect(users.usager.reload.administrateur.procedures.with_discarded).to contain_exactly(procedure, discarded_procedure)
      end
    end

    context 'with the address of an administrateur not tied to ProConnect yet' do
      let(:administrateur) { administrateurs.blank }
      let(:email) { administrateur.email }

      it 'ties it to ProConnect for good' do
        administrateur.update!(pro_connect_required_at: nil)

        migration.grant!(auth:)

        expect(administrateur.reload.pro_connect_required_at).not_to be_nil
      end
    end

    context 'with the address of an instructeur' do
      let(:instructeur) { instructeurs.default }
      let(:email) { instructeur.email }

      it 'merges the recorded groups with its own' do
        own_groupes = instructeur.groupe_instructeurs.to_a

        migration.grant!(auth:)

        expect(instructeur.reload.groupe_instructeurs).to match_array((own_groupes + [groupe, other_groupe]).uniq)
      end
    end
  end
end
