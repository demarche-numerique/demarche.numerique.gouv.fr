# frozen_string_literal: true

describe Administrateurs::ProcedureAdministrateursController, type: :controller do
  let(:signed_in_admin) { administrateurs.default.tap { it.user.update(last_sign_in_at: Time.zone.now) } }
  let(:other_admin) { create(:administrateur).tap { _1.user.update(last_sign_in_at: Time.zone.now) } }
  let!(:administrateurs_procedure) { create(:administrateurs_procedure, administrateur: signed_in_admin, procedure: procedure, manager: manager) }
  let!(:procedure) { create(:procedure, administrateurs: [other_admin]) }
  let(:streams) { Nokogiri::HTML5.fragment(response.body) }
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

      it 'lists the procedure administrateurs' do
        expect(subject.body).to have_css('h1', text: 'Administrateurs')
        expect(subject.body).to have_css('table caption', text: 'Liste des administrateurs')
        expect(subject.body).to have_css('tbody#administrateurs tr', count: 2)
        expect(subject.body).to have_css('tbody#administrateurs tr', text: signed_in_admin.email)
        expect(subject.body).to have_css('tbody#administrateurs tr', text: other_admin.email)
      end
    end
  end

  describe '#create' do
    context 'as manager' do
      let(:manager) { true }
      subject { post :create, params: { procedure_id: procedure.id, administrateur: { email: administrateurs.default.email } }, format: :turbo_stream }
      it { is_expected.to have_http_status(:forbidden) }
    end

    context 'as a regular admin' do
      let(:manager) { false }
      let(:new_admin) { administrateurs.blank }
      let(:email) { new_admin.email }

      subject { post :create, params: { procedure_id: procedure.id, administrateur: { email: } }, format: :turbo_stream }

      before { subject }

      it 'refreshes the list, resets the form and focuses it' do
        expect(streams.css('turbo-stream[action="update"][target="administrateurs"] template tr').text).to include(new_admin.email, other_admin.email)
        expect(streams.at_css('turbo-stream[action="replace"][target="new_administrateur"] template form#new_administrateur input#administrateur_email[required][value=""]')).to be_present
        expect(streams.at_css('turbo-stream[action="focus"][target="administrateur_email"]')).to be_present
      end

      context 'with an unknown email' do
        let(:email) { 'unknown@exemple.fr' }

        it 'only shows an alert' do
          expect(response.body).to include('alert-danger')
          expect(streams.at_css('turbo-stream[target="administrateurs"]')).to be_nil
          expect(streams.at_css('turbo-stream[target="new_administrateur"]')).to be_nil
        end
      end
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

      it 'refreshes the list and focuses the email field once a single admin remains' do
        rows = streams.css('turbo-stream[action="update"][target="administrateurs"] template tr').text
        expect(rows).to include(signed_in_admin.email)
        expect(rows).not_to include(other_admin.email)
        expect(streams.at_css('turbo-stream[action="focus"][target="administrateur_email"]')).to be_present
      end

      context 'when several admins remain' do
        let!(:procedure) { create(:procedure, administrateurs: [other_admin, administrateurs.blank]) }

        it 'focuses the first remove button' do
          expect(streams.at_css('turbo-stream[action="focus"][targets^="#administrateurs tr:first-child"]')).to be_present
          expect(streams.at_css('turbo-stream[action="focus"][target="administrateur_email"]')).to be_nil
        end
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
