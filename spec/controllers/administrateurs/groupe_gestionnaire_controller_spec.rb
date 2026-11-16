# frozen_string_literal: true

describe Administrateurs::GroupeGestionnaireController, type: :controller do
  let(:admin) { administrateurs.default }

  render_views

  describe "#show" do
    subject { get :show }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      let(:gestionnaire) { create(:gestionnaire) }
      let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire], administrateurs: [admin]) }
      before do
        sign_in(admin.user)
        subject
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire)).to eq(groupe_gestionnaire)
        expect(response.body).to have_css('h2', text: "Gestion du groupe gestionnaire \"#{groupe_gestionnaire.name}\"")
        expect(response.body).to have_link(href: admin_groupe_gestionnaire_gestionnaires_path)
        expect(response.body).to have_link(href: admin_groupe_gestionnaire_administrateurs_path)
        expect(response.body).to have_link(href: admin_groupe_gestionnaire_commentaires_path)
      end
    end
  end

  describe "#gestionnaires" do
    subject { get :gestionnaires }
    let(:gestionnaire) { create(:gestionnaire) }
    let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire], administrateurs: [admin]) }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      before do
        sign_in(admin.user)
        subject
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire)).to eq(groupe_gestionnaire)
        expect(response.body).to have_css('h1', text: "Gestionnaires de «\u00A0#{groupe_gestionnaire.name}\u00A0»")
        expect(response.body).to have_css('tbody#gestionnaires td', text: gestionnaire.email)
      end
    end
  end

  describe "#administrateurs" do
    subject { get :administrateurs }
    let(:gestionnaire) { create(:gestionnaire) }
    let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire], administrateurs: [admin]) }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      before do
        sign_in(admin.user)
        subject
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire)).to eq(groupe_gestionnaire)
        expect(response.body).to have_css('h1', text: "Administrateurs de «\u00A0#{groupe_gestionnaire.name}\u00A0»")
        expect(response.body).to have_css('tbody#administrateurs td', text: admin.email)
      end
    end
  end

  describe '#commentaires' do
    let(:gestionnaire) { create(:gestionnaire) }
    let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire], administrateurs: [admin]) }
    subject { get :commentaires }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      before do
        sign_in(admin.user)
      end

      it { expect(subject).to have_http_status(:ok) }
    end
  end

  describe "#create_commentaire" do
    let(:gestionnaire) { create(:gestionnaire) }
    let!(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire], administrateurs: [admin]) }
    let(:body) { "avant\napres" }

    subject {
      post :create_commentaire, params: {
        commentaire_groupe_gestionnaire: {
          body: body,
        },
      }
    }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      let(:gestionnaire_2) { create(:gestionnaire) }

      before do
        groupe_gestionnaire.gestionnaires << gestionnaire_2
        sign_in(admin.user)
      end

      it "creates a commentaire" do
        expect { subject }.to change(CommentaireGroupeGestionnaire, :count).by(1)

        expect(response).to redirect_to(admin_groupe_gestionnaire_commentaires_path)
        expect(flash.notice).to be_present
      end

      it '2 emails are sent' do
        expect { perform_enqueued_jobs { subject } }.to change { ActionMailer::Base.deliveries.count }.by(2)
      end
    end
  end
end
