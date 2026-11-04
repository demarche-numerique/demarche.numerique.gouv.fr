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
end
