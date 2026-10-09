# frozen_string_literal: true

describe Manager::AdministrateursController, type: :controller do
  let(:super_admin) { create(:super_admin) }
  let(:administrateur) { administrateurs.default }

  before do
    sign_in super_admin
  end

  describe '#show' do
    let(:subject) { get :show, params: { id: administrateur.id } }

    context 'with 2FA not enabled' do
      let(:super_admin) { create(:super_admin, otp_required_for_login: false) }
      it { expect(subject).to redirect_to(edit_super_admin_otp_path) }
    end

    context 'with 2FA enabled' do
      render_views
      let(:super_admin) { create(:super_admin, otp_required_for_login: true) }

      before do
        subject
      end

      it 'offers to send the invitation again while the administrateur has not signed in' do
        expect(response.body).to include(administrateur.email)
        expect(response.body).to include("renvoyer l’invitation")
      end

      it 'offers to merge an old administrateur into this one' do
        expect(response.body).to include(request_merge_manager_administrateur_path(administrateur))
        expect(response.body).to include('name="otp_attempt"')
      end

      context 'when the administrateur has already signed in' do
        let(:administrateur) { administrateurs.blank.tap { it.user.update!(last_sign_in_at: Time.zone.now) } }

        it { expect(response.body).not_to include("renvoyer l’invitation") }
      end
    end
  end

  describe 'GET #new' do
    render_views
    it 'displays form to create a new admin' do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #create' do
    let(:email) { 'plop@plop.com' }
    let(:password) { SECURE_PASSWORD }

    subject { post :create, params: { administrateur: { email: email } } }

    context 'when email and password are correct' do
      it 'add new administrateur in database' do
        expect { subject }.to change(Administrateur, :count).by(1)
      end

      it 'alert new mail are send' do
        allow(ProConnectService).to receive(:enabled?).and_return(false)
        expect(AdministrationMailer).to receive(:invite_admin).and_return(AdministrationMailer)
        expect(AdministrationMailer).to receive(:deliver_later)
        subject
      end

      it 'invites through ProConnect when the instance has it' do
        allow(ProConnectService).to receive(:enabled?).and_return(true)
        expect(AdministrationMailer).to receive(:invite_admin_via_pro_connect).and_return(AdministrationMailer)
        expect(AdministrationMailer).to receive(:deliver_later)
        subject
      end
    end

    context 'when email or password are missing' do
      let(:email) { '' }

      it { expect { subject }.to change(Administrateur, :count).by(0) }
    end
  end

  describe '#delete_edit' do
    render_views

    it 'renders the confirmation page posting to the deletion' do
      get :delete_edit, params: { id: administrateur.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(administrateur.email)
      expect(response.body).to include("action=\"#{delete_manager_administrateur_path(administrateur)}\"")
    end
  end

  describe '#delete' do
    # deletion needs an admin who owns nothing, not the shared default one
    let(:administrateur) { administrateurs.blank }
    let(:super_admin) { create(:super_admin, :with_otp) }
    let(:otp_attempt) { current_otp_for(super_admin) }

    subject { delete :delete, params: { id: administrateur.id, otp_attempt: } }

    it_behaves_like "a manager action gated by a fresh super-admin OTP" do
      let(:other_administrateur) { create(:administrateur) }
      let(:action_matcher) { change { Administrateur.where(id: [administrateur.id, other_administrateur.id]).count } }
      let(:replay_subject) { -> { delete :delete, params: { id: other_administrateur.id, otp_attempt: } } }
    end

    it 'deletes the admin' do
      subject

      expect(Administrateur.find_by(id: administrateur.id)).to be_nil
    end
  end

  describe 'merging an old administrateur' do
    let(:inviter_super_admin) { create(:super_admin) }
    let(:confirmer_super_admin) { create(:super_admin) }

    let(:administrateur) { administrateurs.default }
    let(:old_administrateur) { administrateurs.blank }

    def valid_q(expires_in: nil, old_administrateur_id: old_administrateur.id)
      payload = { administrateur_id: administrateur.id, old_administrateur_id:, inviter_id: inviter_super_admin.id }
      controller.message_encryptor_service.encrypt_and_sign(payload, purpose: described_class::MERGE_PURPOSE, expires_in:)
    end

    describe '#request_merge' do
      let(:inviter_super_admin) { create(:super_admin, :with_otp) }
      let(:otp_attempt) { current_otp_for(inviter_super_admin) }
      let(:email) { old_administrateur.email }

      before do
        sign_in inviter_super_admin
        post :request_merge, params: { id: administrateur.id, email:, otp_attempt: }
      end

      it "redirects to the link to share with another super admin" do
        expect(response).to redirect_to(%r{\A#{Regexp.escape(merge_link_manager_administrateur_url(administrateur))}\?q=\S{30,}\z})
      end

      it "generates a link that expires after a day" do
        q = Rack::Utils.parse_query(URI(response.location).query)["q"]

        travel_to(25.hours.from_now) do
          expect(controller.message_encryptor_service.decrypt_and_verify(q, purpose: described_class::MERGE_PURPOSE)).to be_nil
        end
      end

      context "when the email is pasted with capitals and spaces" do
        let(:email) { "  #{old_administrateur.email.upcase} " }

        it { expect(response.location).to start_with(merge_link_manager_administrateur_url(administrateur)) }
      end

      context "when no administrateur has this email" do
        let(:email) { "unknown@example.fr" }

        it do
          expect(flash[:alert]).to include("unknown@example.fr")
          expect(response).to redirect_to(manager_administrateur_path(administrateur))
        end
      end

      context "when the OTP code is missing" do
        let(:otp_attempt) { nil }

        it "does not generate the link" do
          expect(response.location).not_to include(merge_link_manager_administrateur_path(administrateur))
          expect(flash[:error]).to include("Code OTP invalide ou manquant")
        end
      end

      context "when the OTP code is invalid" do
        let(:otp_attempt) { (current_otp_for(inviter_super_admin).to_i + 1).to_s.rjust(6, '0') }

        it "does not generate the link" do
          expect(response.location).not_to include(merge_link_manager_administrateur_path(administrateur))
          expect(flash[:error]).to include("Code OTP invalide ou manquant")
        end
      end
    end

    describe '#merge_link' do
      render_views

      before { sign_in inviter_super_admin }

      it "shows the confirmation url to share with another super admin" do
        get :merge_link, params: { id: administrateur.id, q: valid_q }

        expect(response.body).to include("Veuillez partager ce lien", old_administrateur.email)
        expect(response.body).to match(%r{#{Regexp.escape(merge_edit_manager_administrateur_path(administrateur))}\?q=\S{30,}})
      end

      it "rejects an invalid link" do
        get :merge_link, params: { id: administrateur.id, q: "something that is invalid" }

        expect(flash[:error]).to match(/Le lien que vous avez utilisé est invalide/)
      end
    end

    describe '#merge_edit' do
      render_views

      subject(:new_request) { get :merge_edit, params: { id: administrateur.id, q: valid_q } }

      context "when the current super admin generated the link" do
        before { sign_in inviter_super_admin }

        it "refuses" do
          new_request
          expect(flash[:alert]).to match(/Veuillez partager ce lien avec un autre super administrateur/)
          expect(response).to redirect_to(manager_administrateur_path(administrateur))
        end
      end

      context "when another super admin opens the link" do
        before { sign_in confirmer_super_admin }

        it "asks for confirmation" do
          new_request
          expect(response).to render_template(:merge_edit)
          expect(response.body).to include(inviter_super_admin.email, administrateur.email, old_administrateur.email)
        end
      end
    end

    describe '#merge' do
      subject(:create_request) { post :merge, params: { id: administrateur_id, q: } }

      let!(:procedure) { create(:procedure, administrateurs: [old_administrateur]) }
      let(:administrateur_id) { administrateur.id }
      let(:q) { valid_q }

      context "when another super admin confirms" do
        before { sign_in confirmer_super_admin }

        it "moves the old administrateur's procedures to the administrateur" do
          create_request

          expect(procedure.reload.administrateurs).to eq([administrateur])
          expect(flash[:notice]).to include(administrateur.email, old_administrateur.email)
          expect(response).to redirect_to(manager_administrateur_path(administrateur))
        end
      end

      context "when the current super admin generated the link" do
        before { sign_in inviter_super_admin }

        it "does not merge" do
          create_request

          expect(procedure.reload.administrateurs).to eq([old_administrateur])
          expect(flash[:alert]).to match(/Veuillez partager ce lien avec un autre super administrateur/)
        end
      end

      context "when the current super admin is the administrateur receiving the procedures" do
        let(:administrateur) { create(:administrateur, email: confirmer_super_admin.email) }

        before { sign_in confirmer_super_admin }

        it "does not merge" do
          create_request

          expect(procedure.reload.administrateurs).to eq([old_administrateur])
          expect(flash[:alert]).to match(/Veuillez partager ce lien avec un autre super administrateur/)
        end
      end

      context "when the administrateur_id is tampered in the URL" do
        let(:other_administrateur) { create(:administrateur) }
        let(:administrateur_id) { other_administrateur.id }

        before { sign_in confirmer_super_admin }

        it "does not merge" do
          create_request

          expect(procedure.reload.administrateurs).to eq([old_administrateur])
          expect(flash[:error]).to match(/Le lien que vous avez utilisé est invalide/)
          expect(response).to redirect_to(manager_administrateur_path(other_administrateur))
        end
      end

      context "when the link is invalid" do
        let(:q) { "something that is invalid" }

        before { sign_in confirmer_super_admin }

        it do
          create_request
          expect(flash[:error]).to match(/Le lien que vous avez utilisé est invalide/)
        end
      end

      context "when the old administrateur no longer exists" do
        let(:q) { valid_q(old_administrateur_id: 0) }

        before { sign_in confirmer_super_admin }

        it do
          create_request
          expect(flash[:error]).to match(/Le lien que vous avez utilisé est invalide/)
        end
      end

      context "when the link has expired" do
        let(:q) { valid_q(expires_in: 1.day) }

        before { sign_in confirmer_super_admin }

        it "does not merge" do
          q
          travel_to(2.days.from_now) { create_request }

          expect(procedure.reload.administrateurs).to eq([old_administrateur])
          expect(flash[:error]).to match(/Le lien que vous avez utilisé est invalide/)
        end
      end
    end
  end

  describe '#index' do
    render_views

    it 'searches admin by email' do
      get :index, params: { search: administrateur.email }
      expect(response).to have_http_status(:success)
    end
  end
end
