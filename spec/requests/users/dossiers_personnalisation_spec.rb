# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::DossiersPersonnalisation', type: :request do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  describe 'GET /dossiers/personnalisation/edit' do
    context 'avec 5 dossiers ou moins' do
      before { create_list(:dossier, 5, user:) }

      it 'redirige vers /dossiers' do
        get edit_users_dossiers_personnalisation_path
        expect(response).to redirect_to(dossiers_path)
      end
    end

    context 'avec plus de 5 dossiers' do
      before { create_list(:dossier, 6, user:, procedure: create(:procedure, :published)) }

      it 'rend la page' do
        get edit_users_dossiers_personnalisation_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('users.dossiers_personnalisation.edit.titre'))
      end
    end
  end
end
