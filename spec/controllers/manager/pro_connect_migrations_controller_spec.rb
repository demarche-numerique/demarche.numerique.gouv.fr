# frozen_string_literal: true

describe Manager::ProConnectMigrationsController, type: :controller do
  render_views

  let(:account) { administrateurs.default.user }
  let(:shared) { true }
  let!(:origin) do
    ProConnectMigration.create!(
      user: account, source_email: 'contact@exemple.fr', pro_connect_email: account.email,
      state: :renamed, target_user: account, shared:, code_digest: 'empreinte-du-code'
    )
  end

  before { sign_in create(:super_admin) }

  describe '#index' do
    it 'finds a migration by its old address, and only that one' do
      other = ProConnectMigration.create!(user: users.usager, source_email: 'accueil@ailleurs.fr')

      get :index, params: { search: 'contact@exemple.fr' }

      expect(response.body).to include(manager_pro_connect_migration_path(origin))
      expect(response.body).not_to include(manager_pro_connect_migration_path(other))
    end
  end

  describe '#show' do
    subject { get :show, params: { id: origin.id } }

    it 'shows the old address without the code digest' do
      subject

      expect(response.body).to include('contact@exemple.fr', 'ouvert aux co-titulaires')
      expect(response.body).not_to include('empreinte-du-code')
      expect(response.body).not_to include('a repris l’ancienne adresse')
    end

    context 'when an unrelated account took the old address' do
      let!(:taker) { create(:user, email: 'contact@exemple.fr') }

      it 'names the account and says the next co-holders are blocked' do
        subject

        expect(response.body).to include(manager_user_path(taker))
        expect(response.body).to include('sans lien avec cette migration')
        expect(response.body).to include('Les co-titulaires suivants')
      end

      context 'when the holder answered that the account was not shared' do
        let(:shared) { false }

        it 'names the account without announcing any blocked co-holder' do
          subject

          expect(response.body).to include(manager_user_path(taker), 'fermé aux co-titulaires')
          expect(response.body).not_to include('Les co-titulaires suivants')
        end
      end
    end

    context 'when a co-holder kept the old address on ProConnect' do
      let!(:taker) { create(:user, email: 'contact@exemple.fr') }

      let!(:granted) do
        ProConnectMigration.create!(user: account, source_email: 'contact@exemple.fr', parent: origin, state: :granted, target_user: taker)
      end

      it 'says the account comes from this migration' do
        subject

        expect(response.body).to include(manager_user_path(taker))
        expect(response.body).to include('ouvert par un co-titulaire', 'adresse nominative')
        expect(response.body).not_to include('le supprimer s’il est vide')
      end

      it 'links the migration of the co-holder to the one of the holder' do
        get :show, params: { id: granted.id }

        expect(response.body).to include(manager_pro_connect_migration_path(origin))
        expect(response.body).not_to include('ouvert aux co-titulaires')
      end
    end
  end
end
