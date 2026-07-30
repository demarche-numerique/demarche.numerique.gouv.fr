# frozen_string_literal: true

include ActionView::Helpers::SanitizeHelper

describe Manager::DossiersController, type: :controller do
  let(:super_admin) { create(:super_admin, :with_otp) }
  before do
    sign_in super_admin
    procedure = create(:procedure, :published, types_de_champ_public: types_de_champ)
    @dossier = create(:dossier, :en_construction, :with_populated_champs, procedure:)
  end

  let(:types_de_champ) { [] }

  render_views

  describe 'GET #index' do
    it "should list dossiers" do
      get :index
      expect(response.body).to include(@dossier.procedure.libelle)
    end
  end

  describe "GET #show" do
    let(:types_de_champ) {
      [
        { libelle: "Nom", mandatory: true },
      ]
    }

    before do
      get :show, params: { id: @dossier.id }
    end

    subject { strip_tags(response.body) }

    it { expect(subject).to match(%r{Nom\s+\*\s+Texte court\s+🟢\s+rempli}) }
  end

  describe "POST #transfer" do
    let(:otp_attempt) { current_otp_for(super_admin) }
    let(:email) { "chouette.gars@laposte.net" }

    subject do
      post :transfer, params: { id: @dossier.id, email:, otp_attempt: }
    end

    it_behaves_like "a manager action gated by a fresh super-admin OTP" do
      let(:action_matcher) { have_enqueued_mail(DossierMailer, :notify_transfer) }
      let(:replay_subject) do
        -> { post :transfer, params: { id: @dossier.id, email: "second.gars@laposte.net", otp_attempt: otp_attempt } }
      end
    end

    context 'with valid email' do
      it do
        expect { subject }.to have_enqueued_mail(DossierMailer, :notify_transfer)
        expect(flash[:notice]).to eq("Une invitation de transfert a été envoyée à chouette.gars@laposte.net")
      end
    end

    context 'with invalid email' do
      let(:email) { "chouette" }

      it do
        expect { subject }.not_to have_enqueued_mail(DossierMailer, :notify_transfer)
        expect(flash[:alert]).to eq("L’adresse électronique est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com")
      end
    end
  end

  describe "DELETE #transfer_destroy" do
    before do
      DossierTransfer.create(email: 'coucou@laposte.net', dossiers: [@dossier])
      delete :transfer_destroy, params: { id: @dossier.id }
    end

    it do
      expect(@dossier.transfer).to be_nil
      expect(flash[:notice]).to eq "La proposition de transfert a été annulée."
    end
  end
end
