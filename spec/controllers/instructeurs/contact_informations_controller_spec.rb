# frozen_string_literal: true

describe Instructeurs::ContactInformationsController, type: :controller do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure) }
  let(:assign_to) { create(:assign_to, instructeur: instructeur, groupe_instructeur: build(:groupe_instructeur, procedure: procedure)) }
  let(:gi) { assign_to.groupe_instructeur }
  let(:from_admin) { nil }

  let(:other_procedure) { create(:procedure) }
  let(:other_assign_to) { create(:assign_to, instructeur: instructeur, groupe_instructeur: build(:groupe_instructeur, procedure: other_procedure)) }
  let(:other_gi) { other_assign_to.groupe_instructeur }

  before do
    sign_in(instructeur.user)
  end

  describe '#create' do
    context 'when submitting a new contact_information' do
      let(:params) do
        {
          contact_information: {
            nom: 'super service',
            email: 'email@toto.com',
            telephone: '1234',
            horaires: 'horaires',
            adresse: 'adresse',
          },
          procedure_id: procedure.id,
          groupe_id: gi.id,
        }
      end

      it do
        post :create, params: params
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq('Les informations de contact ont bien été ajoutées')
        expect(ContactInformation.last.nom).to eq('super service')
        expect(ContactInformation.last.email).to eq('email@toto.com')
        expect(ContactInformation.last.telephone).to eq('1234')
        expect(ContactInformation.last.horaires).to eq('horaires')
        expect(ContactInformation.last.adresse).to eq('adresse')
      end
    end

    context 'when submitting an invalid contact_information' do
      before do
        post :create, params: params
      end

      let(:params) {
        {
          contact_information: {
            nom: 'super service',
          },
          procedure_id: procedure.id,
          groupe_id: gi.id,
        }
      }

      it do
        expect(flash.alert).not_to be_nil
        expect(response).to render_template(:new)
        expect(assigns(:contact_information).nom).to eq('super service')
      end
    end
  end

  describe '#update' do
    let(:contact_information) { create(:contact_information, groupe_instructeur: gi) }
    let(:contact_information_params) {
      {
        nom: 'nom',
      }
    }
    let(:params) {
      {
        id: contact_information.id,
        contact_information: contact_information_params,
        procedure_id: procedure.id,
        groupe_id: gi.id,
        from_admin: from_admin,
      }
    }

    before do
      patch :update, params: params
    end

    context 'when updating a contact_information' do
      it do
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq('Les informations de contact ont bien été modifiées')
        expect(ContactInformation.last.nom).to eq('nom')
        expect(response).to redirect_to(instructeur_groupe_path(gi, procedure_id: procedure.id))
      end
    end

    context 'when updating a contact_information with invalid data' do
      let(:contact_information_params) { { nom: '' } }

      it do
        expect(flash.alert).not_to be_nil
        expect(response).to render_template(:edit)
      end
    end
  end

  describe '#destroy' do
    let(:contact_information) { create(:contact_information, groupe_instructeur: gi) }

    before do
      delete :destroy, params: { id: contact_information.id, procedure_id: procedure.id, groupe_id: gi.id }
    end

    it do
      expect { contact_information.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(flash.alert).to be_nil
      expect(flash.notice).to eq("Les informations de contact ont bien été supprimées")
      expect(response).to redirect_to(instructeur_groupe_path(gi, procedure_id: procedure.id))
    end
  end

  context 'when procedure_id and groupe_id belong to different procedures' do
    before do
      gi       # instructeur has legitimate access to `procedure` via gi
      other_gi # instructeur is also a member of other_gi on other_procedure
    end

    let(:valid_contact_information_params) do
      {
        nom: 'cross service',
        email: 'email@toto.com',
        telephone: '1234',
        horaires: 'horaires',
        adresse: 'adresse',
      }
    end

    describe '#create' do
      subject(:mismatched_create) do
        post :create, params: {
          contact_information: valid_contact_information_params,
          procedure_id: procedure.id,
          groupe_id: other_gi.id,
        }
      end

      it 'does not create a contact_information on the other procedure groupe' do
        expect { mismatched_create rescue nil }.not_to change { ContactInformation.count }
        expect(other_gi.reload.contact_information).to be_nil
      end
    end

    describe '#update' do
      let!(:other_contact_information) { create(:contact_information, groupe_instructeur: other_gi, nom: 'original') }

      subject(:mismatched_update) do
        patch :update, params: {
          id: other_contact_information.id,
          contact_information: { nom: 'tampered' },
          procedure_id: procedure.id,
          groupe_id: other_gi.id,
        }
      end

      it 'does not modify the other procedure groupe contact_information' do
        expect { mismatched_update rescue nil }.not_to change { other_contact_information.reload.nom }
      end
    end

    describe '#destroy' do
      let!(:other_contact_information) { create(:contact_information, groupe_instructeur: other_gi) }

      subject(:mismatched_destroy) do
        delete :destroy, params: {
          id: other_contact_information.id,
          procedure_id: procedure.id,
          groupe_id: other_gi.id,
        }
      end

      it 'does not destroy the other procedure groupe contact_information' do
        expect { mismatched_destroy rescue nil }.not_to change { ContactInformation.exists?(other_contact_information.id) }
      end
    end
  end
end
