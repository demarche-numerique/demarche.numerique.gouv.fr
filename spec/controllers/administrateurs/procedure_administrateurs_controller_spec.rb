# frozen_string_literal: true

describe Administrateurs::ProcedureAdministrateursController, type: :controller do
  let(:signed_in_admin) { administrateurs.default.tap { it.user.update(last_sign_in_at: Time.zone.now) } }
  let(:other_admin) { create(:administrateur).tap { _1.user.update(last_sign_in_at: Time.zone.now) } }
  let!(:administrateurs_procedure) { create(:administrateurs_procedure, administrateur: signed_in_admin, procedure: procedure, manager: manager) }
  let!(:procedure) { create(:procedure, administrateurs: [other_admin]) }
  render_views

  before do
    sign_in(signed_in_admin.user)
  end

  describe '#index' do
    subject { get :index, params: { procedure_id: procedure.id } }

    context 'as a regular admin' do
      let(:manager) { false }

      it 'renders the add admin form' do
        expect(subject.body).to have_css("form#new_administrateur label[for='administrateur_email'] .fr-hint-text", text: procedure.libelle)
        expect(subject.body).to have_field('administrateur_email', type: 'email')
        expect(subject.body).to have_button('Ajouter comme administrateur')
      end
    end
  end

  describe '#create' do
    context 'as manager' do
      let(:manager) { true }
      subject { post :create, params: { procedure_id: procedure.id, administrateur: { email: administrateurs.default.email } }, format: :turbo_stream }
      it { is_expected.to have_http_status(:forbidden) }
    end
  end

  describe '#destroy' do
    let(:manager) { false }

    def destroy_admin(admin_to_remove)
      delete :destroy, params: { procedure_id: procedure.id, id: admin_to_remove.id }, format: :turbo_stream
    end

    context 'when removing another admin' do
      before do
        destroy_admin(other_admin)
      end

      it 'removes the admin from the procedure' do
        expect(response.body).to include('alert-success')
        expect(other_admin.procedures.reload).not_to include(procedure)
      end

      context 'then removing oneself' do
        before do
          destroy_admin(signed_in_admin)
        end

        it 'removes the admin from the procedure' do
          expect(response.body).to include('alert-danger')
          expect(signed_in_admin.procedures.reload).to include(procedure)
        end
      end
    end

    context 'when removing oneself from a procedure' do
      before do
        destroy_admin(signed_in_admin)
      end

      it 'removes the admin from the procedure' do
        expect(response).to redirect_to admin_procedures_path
        expect(signed_in_admin.procedures.reload).not_to include(procedure)
      end
    end
  end
end
