# frozen_string_literal: true

describe Gestionnaires::GroupeGestionnaireCommentairesController, type: :controller do
  let(:gestionnaire) { create(:gestionnaire).tap { _1.user.update(last_sign_in_at: Time.zone.now) } }
  let(:administrateur) { administrateurs.default }
  let(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire], administrateurs: [administrateur]) }
  let!(:commentaire) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire: groupe_gestionnaire, sender: administrateur) }

  describe "#index" do
    let(:subject_gestionnaire) { gestionnaire }
    let(:subject_groupe_gestionnaire) { groupe_gestionnaire }
    render_views
    subject { get :index, params: { groupe_gestionnaire_id: subject_groupe_gestionnaire.id } }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    describe "when logged in" do
      before do
        sign_in(subject_gestionnaire.user)
        subject
      end

      context "in a root group" do
        it do
          expect(response).to have_http_status(:ok)
          expect(assigns(:groupe_gestionnaire).current_commentaires_groupe_and_children_commentaires_groupe.select("sender_id, sender_type, sender_email, MAX(id) as id, MAX(created_at) as created_at").group(:sender_id, :sender_type, :sender_email).order("MAX(id) DESC")).to include(commentaire)
          expect(response.body).to include(commentaire.sender_email)
          expect(response.body).not_to include("Messages avec le groupe gestionnaire parent")
        end
      end

      context "with a message from a child group" do
        let(:child_gestionnaire) { create(:gestionnaire) }
        let(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire.id}/", gestionnaires: [child_gestionnaire]) }
        let(:child_commentaire) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire: child_groupe_gestionnaire, sender: child_gestionnaire) }
        let(:subject_groupe_gestionnaire) { child_commentaire.groupe_gestionnaire.parent }

        it do
          expect(response.body).to have_css("main h2", text: "Messagerie des groupes enfants")
          expect(response.body).not_to have_css("main h3, main h4, main h5, main h6")
          expect(response.body).to have_css("tbody tr", text: child_gestionnaire.email)
        end
      end

      context "in a child group" do
        let(:child_gestionnaire) { create(:gestionnaire).tap { _1.user.update(last_sign_in_at: Time.zone.now) } }
        let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire.id}/", gestionnaires: [child_gestionnaire]) }
        let(:subject_groupe_gestionnaire) { child_groupe_gestionnaire }
        let(:subject_gestionnaire) { child_gestionnaire }
        let!(:commentaire_to_parent_groupe_gestionnaire) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire: child_groupe_gestionnaire, sender: child_gestionnaire) }

        it do
          expect(response).to have_http_status(:ok)
          expect(assigns(:groupe_gestionnaire).current_commentaires_groupe_and_children_commentaires_groupe.or(CommentaireGroupeGestionnaire.where(groupe_gestionnaire_id: child_groupe_gestionnaire.id, sender: child_gestionnaire)).select("sender_id, sender_type, sender_email, MAX(id) as id, MAX(created_at) as created_at").group(:sender_id, :sender_type, :sender_email).order("MAX(id) DESC")).to include(commentaire_to_parent_groupe_gestionnaire)
          expect(response.body).to include(commentaire_to_parent_groupe_gestionnaire.sender_email)
          expect(response.body).to include("Messages avec le groupe gestionnaire parent")
          expect(response.body).to have_css("main h2", text: "Messagerie du groupe parent")
          expect(response.body).not_to have_css("main h3, main h4, main h5, main h6")
        end
      end
    end
  end

  describe "#show" do
    render_views
    subject { get :show, params: { groupe_gestionnaire_id: groupe_gestionnaire.id, id: commentaire.id } }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      before do
        sign_in(gestionnaire.user)
        subject
      end

      it do
        expect(response).to have_http_status(:ok)
        expect(assigns(:groupe_gestionnaire).commentaire_groupe_gestionnaires.where(sender: administrateur)).to include(commentaire)
        expect(response.body).to include(commentaire.body)
      end
    end
  end

  describe "#create" do
    before do
      sign_in(gestionnaire.user)
      post :create,
        params: {
          id: commentaire.id,
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          commentaire_groupe_gestionnaire: { body: "avant\napres" },
        }
    end

    context 'of a new commentaire' do
      it do
        expect(groupe_gestionnaire.reload.commentaire_groupe_gestionnaires.map(&:body)).to include("avant\napres")
        expect(flash.notice).to eq("Message envoyé")
      end
    end
  end

  describe "#parent_groupe_gestionnaire" do
    let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire.id}/", gestionnaires: [gestionnaire]) }
    render_views
    subject { get :parent_groupe_gestionnaire, params: { groupe_gestionnaire_id: child_groupe_gestionnaire.id } }

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    describe "when logged in" do
      before do
        sign_in(gestionnaire.user)
        subject
      end

      context "without a commentaire to parent_group_gestionnaire" do
        it do
          expect(response).to have_http_status(:ok)
          expect(assigns(:groupe_gestionnaire).commentaire_groupe_gestionnaires.where(sender: gestionnaire)).not_to include(commentaire)
          expect(response.body).not_to include(commentaire.body)
        end
      end

      context "with a commentaire to parent_group_gestionnaire" do
        let!(:commentaire) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire: child_groupe_gestionnaire, sender: gestionnaire) }

        it do
          expect(response).to have_http_status(:ok)
          expect(assigns(:groupe_gestionnaire).commentaire_groupe_gestionnaires.where(sender: gestionnaire)).to include(commentaire)
          expect(response.body).to include(commentaire.body)
        end
      end
    end
  end

  describe "#create_parent_groupe_gestionnaire" do
    let!(:child_groupe_gestionnaire) { create(:groupe_gestionnaire, ancestry: "/#{groupe_gestionnaire.id}/", gestionnaires: [gestionnaire]) }
    before do
      sign_in(gestionnaire.user)
      post :create_parent_groupe_gestionnaire,
        params: {
          id: commentaire.id,
          groupe_gestionnaire_id: child_groupe_gestionnaire.id,
          commentaire_groupe_gestionnaire: { body: "avant\napres" },
        }
    end

    context 'of a new commentaire' do
      it do
        expect(child_groupe_gestionnaire.reload.commentaire_groupe_gestionnaires.map(&:body)).to include("avant\napres")
        expect(flash.notice).to eq("Message envoyé")
      end
    end
  end

  describe "#destroy" do
    render_views

    before do
      sign_in(gestionnaire.user)
    end

    def remove_commentaire(commentaire)
      delete :destroy,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          id: commentaire_to_delete.id,
        },
        format: :turbo_stream
    end

    context 'when the commentaire was created by the gestionnaire' do
      let(:commentaire_to_delete) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire: groupe_gestionnaire, gestionnaire: gestionnaire, sender: administrateur) }

      before { remove_commentaire(commentaire_to_delete) }

      it do
        expect(groupe_gestionnaire.reload.commentaire_groupe_gestionnaires.count).to eq(2)
        expect(commentaire_to_delete.reload.discarded?).to eq(true)
        expect(response.body).to include("Votre message a été supprimé")
        expect(response.body).to have_css("turbo-stream[action='update'][target='#{ActionView::RecordIdentifier.dom_id(commentaire_to_delete)}']")
        expect(response.body).to include("(Message supprimé)")
      end
    end

    context 'when the commentaire was not created by the gestionnaire' do
      let(:commentaire_to_delete) { commentaire }

      before { remove_commentaire(commentaire_to_delete) }

      it do
        expect(groupe_gestionnaire.reload.commentaire_groupe_gestionnaires.count).to eq(1)
        expect(commentaire_to_delete.reload.discarded?).to eq(false)
        expect(response.body).to include("Impossible de supprimer le message, celui-ci ne vous appartient pas")
        expect(response.body).not_to have_css("turbo-stream[action='update'][target='#{ActionView::RecordIdentifier.dom_id(commentaire_to_delete)}']")
      end
    end
  end
end
