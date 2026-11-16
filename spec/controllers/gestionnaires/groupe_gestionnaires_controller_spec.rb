# frozen_string_literal: true

describe Gestionnaires::GroupeGestionnairesController, type: :controller do
  let(:gestionnaire) { create(:gestionnaire) }

  render_views

  describe "#index" do
    subject { get :index }

    context "when not logged" do
      it do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
      let!(:other_groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
      let!(:not_my_groupe_gestionnaire) { create(:groupe_gestionnaire) }
      before do
        sign_in(gestionnaire.user)
      end

      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaires)).to include(groupe_gestionnaire)
        expect(assigns(:groupe_gestionnaires)).to include(other_groupe_gestionnaire)
        expect(assigns(:groupe_gestionnaires)).not_to include(not_my_groupe_gestionnaire)
        expect(response.body).to have_link('Mes groupes gestionnaires', href: gestionnaire_groupe_gestionnaires_path, class: 'fr-nav__link')
        expect(response.body).to have_css('#header-navigation [aria-current="page"]', text: 'Mes groupes gestionnaires')
      end
    end
  end

  describe "#show" do
    subject { get :show, params: { id: child_groupe_gestionnaire.id } }
    let!(:groupe_gestionnaire_root) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
    let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire_root.id}/", gestionnaires: [gestionnaire]) }

    context "when not logged" do
      it do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      before do
        sign_in(gestionnaire.user)
      end

      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire)).to eq(child_groupe_gestionnaire)
        expect(response.body).to have_link('Mes groupes gestionnaires', href: gestionnaire_groupe_gestionnaires_path)
        expect(response.body).not_to have_css('#header-navigation [aria-current]')
      end
    end
  end

  describe "#edit" do
    subject { get :edit, params: { id: child_groupe_gestionnaire.id } }
    let!(:groupe_gestionnaire_root) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
    let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire_root.id}/", gestionnaires: [gestionnaire]) }

    context "when not logged" do
      it do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      before do
        sign_in(gestionnaire.user)
      end

      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire)).to eq(child_groupe_gestionnaire)
      end
    end
  end

  describe "#update" do
    subject { post :update, params: { id: child_groupe_gestionnaire.id, groupe_gestionnaire: { name: 'new child name' } } }
    let!(:groupe_gestionnaire_root) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
    let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire_root.id}/", gestionnaires: [gestionnaire]) }

    context "when not logged" do
      it do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      before do
        sign_in(gestionnaire.user)
      end

      it do
        subject
        expect(child_groupe_gestionnaire.reload.name).to eq('new child name')
        expect(response).to redirect_to(gestionnaire_groupe_gestionnaire_path(child_groupe_gestionnaire))
      end
    end
  end

  describe "#destroy" do
    subject { post :destroy, params: { id: child_groupe_gestionnaire.id } }
    let!(:groupe_gestionnaire_root) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
    let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire_root.id}/", gestionnaires: [gestionnaire]) }

    context "when not logged" do
      it do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      before do
        sign_in(gestionnaire.user)
      end

      it do
        subject
        expect(GroupeGestionnaire.count).to eq(1)
        expect(response).to redirect_to(gestionnaire_groupe_gestionnaires_path)
      end
    end
  end

  describe "#tree_structure" do
    let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
    subject { get :tree_structure, params: { id: groupe_gestionnaire.id } }

    context "when not logged" do
      it do
        subject
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire.id}/", gestionnaires: []) }
      before do
        sign_in(gestionnaire.user)
      end

      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(assigns(:tree_structure)).to eq(groupe_gestionnaire => { child_groupe_gestionnaire => {} })
      end
    end
  end
end
