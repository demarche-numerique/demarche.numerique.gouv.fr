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
end
