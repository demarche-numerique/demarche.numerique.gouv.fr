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

  describe '#completed' do
    render_views

    before { sign_in(account) }

    it 'confirms the migration with the address of the account' do
      account.administrateur.update!(pro_connect_required_at: Time.zone.now)

      get :completed

      expect(response.body).to include('Migration terminée', "<strong>#{account.email}</strong>")
    end

    it 'sends an administrateur not tied to ProConnect to their procedures' do
      get :completed

      expect(response).to redirect_to(admin_procedures_path)
    end
  end
end
