# frozen_string_literal: true

describe Gestionnaires::GroupeGestionnaireChildrenController, type: :controller do
  let(:gestionnaire) { create(:gestionnaire).tap { _1.user.update(last_sign_in_at: Time.zone.now) } }
  let(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }

  render_views

  describe "#index" do
    subject { get :index, params: { groupe_gestionnaire_id: groupe_gestionnaire.id } }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire.id}/", gestionnaires: [gestionnaire]) }
      before do
        sign_in(gestionnaire.user)
        subject
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire).children).to include(child_groupe_gestionnaire)
        expect(response.body).to include(child_groupe_gestionnaire.name)
        expect(response.body).to have_css("h1", text: groupe_gestionnaire.name)
        expect(response.body).to have_field('groupe_gestionnaire_name')
      end
    end
  end

  describe '#create' do
    before do
      sign_in gestionnaire.user
      post :create,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          groupe_gestionnaire: { name: new_child_group_name },
        },
        format: :turbo_stream
    end

    context 'of a child group' do
      let(:new_child_group_name) { 'child group' }

      it do
        expect(groupe_gestionnaire.reload.children.map(&:name)).to include(new_child_group_name)
        expect(response.body).to include("Le groupe enfants a bien été créé")
        expect(response.body).to have_css('turbo-stream[action="replace"][target="new_child"]')
        expect(response.body).to include(new_child_group_name)
      end
    end
  end
end
