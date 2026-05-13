# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::DossiersPersonnalisation', type: :request do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  describe 'PATCH /dossiers/personnalisation' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: 'Titre' }]) }
    let!(:dossiers) { create_list(:dossier, 6, user:, procedure:) }
    let(:type_de_champ) { procedure.active_revision.types_de_champ.first }

    it 'crée la presentation et redirige avec flash' do
      patch users_dossiers_personnalisation_path, params: {
        presentations: { procedure.id.to_s => { displayed_column_ids: [type_de_champ.stable_id.to_s] } },
      }

      expect(response).to redirect_to(dossiers_path)
      expect(flash[:notice]).to eq(I18n.t('users.dossiers_personnalisation.flash.success'))
      expect(UserProcedurePresentation.find_by(user:, procedure:).displayed_columns.size).to eq(1)
    end

    it 'détruit la presentation existante si la sélection est vide' do
      UserProcedurePresentation.create!(user:, procedure:, displayed_columns: type_de_champ.columns(procedure:))

      patch users_dossiers_personnalisation_path, params: {
        presentations: { procedure.id.to_s => { displayed_column_ids: [] } },
      }

      expect(UserProcedurePresentation.find_by(user:, procedure:)).to be_nil
    end

    it 'ignore les procedure_ids étrangères' do
      autre_procedure = create(:procedure, :published)

      patch users_dossiers_personnalisation_path, params: {
        presentations: { autre_procedure.id.to_s => { displayed_column_ids: ['1'] } },
      }

      expect(UserProcedurePresentation.find_by(user:, procedure: autre_procedure)).to be_nil
    end
  end

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
