# frozen_string_literal: true

describe ProConnectMigrationsController, type: :controller do
  let(:account) { administrateurs.default.user }

  describe '#support' do
    render_views

    let(:migration) { ProConnectMigration.create!(user: account, source_email: account.email, state: :domain_mismatch, pro_connect_email: 'camille.dupont@ailleurs.fr') }

    it 'explains why with both addresses' do
      session[ProConnectMigrationConcern::SESSION_KEY] = migration.id

      get :support

      expect(response.body).to include('camille.dupont@ailleurs.fr', account.email)
    end

    it 'sends back to the sign in page without a migration' do
      get :support

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'sends back to the sign in page once the ProConnect return is old' do
      session[ProConnectMigrationConcern::SESSION_KEY] = migration.id
      migration.update!(updated_at: 31.minutes.ago)

      get :support

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
