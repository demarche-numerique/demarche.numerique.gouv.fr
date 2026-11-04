# frozen_string_literal: true

describe ProConnectMigration do
  let(:account) { administrateurs.default.user }
  let(:migration) { ProConnectMigration.create!(user: account, source_email: account.email) }
  let(:user_info) { { 'sub' => 'sub', 'email' => email, 'given_name' => 'Camille', 'usual_name' => 'Dupont' } }

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
      expect { migration.rename!(auth:) }.not_to have_enqueued_mail

      account.reload
      expect(account.email).to eq('camille.dupont@exemple.fr')
      expect(account.valid_password?(users.default_password)).to be true
      expect(administrateur.reload.pro_connect_required_at).not_to be_nil
      expect(account.pro_connect_informations.pluck(:sub)).to eq(['sub'])
      expect(migration).to be_renamed
      expect(migration.procedure_ids).to include(procedure.id)
      expect(migration.procedure_ids).not_to include(support_procedure.id)
      expect(migration.groupe_instructeur_ids).to eq([groupe.id])
    end

    it 'drops the address change and the merge another holder left pending, and trusts the ProConnect address' do
      account.update_columns(unconfirmed_email: 'bob@exemple.fr', requested_merge_into_id: users.usager.id, email_verified_at: nil)

      migration.rename!(auth:)

      account.reload
      expect(account.unconfirmed_email).to be_nil
      expect(account.requested_merge_into).to be_nil
      expect(account.email_verified_at).not_to be_nil
    end

    it 'gives up when the address was taken in the meantime' do
      create(:user, email: 'camille.dupont@exemple.fr')

      expect(migration.rename!(auth:)).to be false
      expect(account.reload.email).to eq(migration.source_email)
    end

    it 'gives up when the account was renamed in the meantime' do
      account.update_column(:email, 'autre@exemple.fr')

      expect(migration.rename!(auth:)).to be false
    end

    it 'gives up with the ProConnect identity of another address' do
      other = auth.with(user_info: { 'sub' => 'other', 'email' => 'dominique.martin@exemple.fr' })

      expect(migration.rename!(auth: other)).to be false
      expect(account.reload.email).to eq(migration.source_email)
    end
  end
end
