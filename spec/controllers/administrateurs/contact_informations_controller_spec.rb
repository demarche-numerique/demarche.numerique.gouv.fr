# frozen_string_literal: true

describe Administrateurs::ContactInformationsController, type: :controller do
  let(:admin) { administrateurs(:default_admin) }
  let(:procedure) { create(:procedure, administrateurs: [admin]) }
  let(:groupe_instructeur) { procedure.defaut_groupe_instructeur }

  before do
    sign_in(admin.user)
  end

  describe '#new' do
    it 'renders the new template' do
      get :new, params: { procedure_id: procedure.id, groupe_instructeur_id: groupe_instructeur.id }
      expect(response).to render_template(:new)
      expect(assigns(:contact_information)).to be_a_new(ContactInformation)
    end
  end

  describe '#create' do
    let(:valid_params) do
      {
        procedure_id: procedure.id,
        groupe_instructeur_id: groupe_instructeur.id,
        contact_information: {
          nom: 'Service Test',
          email: 'contact@test.gouv.fr',
          telephone: '0123456789',
          horaires: '9h-17h',
          adresse: '1 rue de la Paix, 75001 Paris'
        }
      }
    end

    context 'with valid params' do
      it 'creates the contact information and redirects' do
        expect { post :create, params: valid_params }
          .to change { ContactInformation.count }.by(1)

        expect(flash[:notice]).to eq('Les informations de contact ont bien été ajoutées')
        expect(response).to redirect_to(admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur))
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        valid_params.deep_merge(contact_information: { nom: '', email: '' })
      end

      it 'renders the new template with errors' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe '#edit' do
    let!(:contact_information) { create(:contact_information, groupe_instructeur:) }

    it 'renders the edit template' do
      get :edit, params: { procedure_id: procedure.id, groupe_instructeur_id: groupe_instructeur.id }
      expect(response).to render_template(:edit)
      expect(assigns(:contact_information)).to eq(contact_information)
    end
  end

  describe '#update' do
    let!(:contact_information) { create(:contact_information, groupe_instructeur:, nom: 'Old Name') }

    let(:update_params) do
      {
        procedure_id: procedure.id,
        groupe_instructeur_id: groupe_instructeur.id,
        contact_information: { nom: 'New Name' }
      }
    end

    context 'with valid params' do
      it 'updates the contact information and redirects' do
        patch :update, params: update_params

        expect(contact_information.reload.nom).to eq('New Name')
        expect(flash[:notice]).to eq('Les informations de contact ont bien été modifiées')
        expect(response).to redirect_to(admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur))
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        update_params.deep_merge(contact_information: { email: 'invalid' })
      end

      it 'renders the edit template with errors' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe '#destroy' do
    let!(:contact_information) { create(:contact_information, groupe_instructeur:) }

    it 'destroys the contact information and redirects' do
      expect {
        delete :destroy, params: { procedure_id: procedure.id, groupe_instructeur_id: groupe_instructeur.id }
      }.to change { ContactInformation.count }.by(-1)

      expect(flash[:notice]).to eq('Les informations de contact ont bien été supprimées')
      expect(response).to redirect_to(admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur))
    end
  end

  context 'when admin is not an instructeur in the groupe' do
    it 'still allows access to create contact information' do
      expect(groupe_instructeur.instructeurs).not_to include(admin.user.instructeur)

      get :new, params: { procedure_id: procedure.id, groupe_instructeur_id: groupe_instructeur.id }
      expect(response).to have_http_status(:success)
    end
  end
end
