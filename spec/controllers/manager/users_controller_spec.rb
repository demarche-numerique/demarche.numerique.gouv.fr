# frozen_string_literal: true

describe Manager::UsersController, type: :controller do
  let(:super_admin) { create(:super_admin) }

  before { sign_in super_admin }

  describe '#show' do
    render_views

    let(:super_admin) { create(:super_admin) }
    let(:user) { create(:user) }

    before do
      get :show, params: { id: user.id }
    end

    it { expect(response.body).to include(user.email) }

    it 'links to the deletion confirmation page' do
      expect(response.body).to include(delete_edit_manager_user_path(user))
    end

    context 'when the user cannot be deleted' do
      let(:user) { administrateurs.default.user }

      it 'does not offer the deletion' do
        expect(response.body).not_to include(delete_edit_manager_user_path(user))
      end
    end

    context 'when the user has more dossiers than a page holds (5)' do
      let(:owner) { create(:user) }
      let(:dossiers) do
        6.downto(1).map { create(:dossier, user: owner, procedure: procedures.individual, created_at: it.days.ago) }
      end
      let(:user) { dossiers.first.user }

      it 'lists the most recent dossiers first' do
        links = response.body.scan(%r{href="/manager/dossiers/(\d+)"}).flatten.map(&:to_i).uniq
        expect(links).to eq(dossiers.drop(1).reverse.map(&:id))
      end
    end

    context 'when user is blocked' do
      let(:user) { create(:user, blocked_at: Time.zone.now) }

      it 'displays the reactivate button' do
        expect(response.body).to include("Réactiver le compte")
      end
    end
  end

  describe '#resend_reset_password_instructions' do
    let(:super_admin) { create(:super_admin, :with_otp) }
    let(:user) { administrateurs.default.user }

    subject { post :resend_reset_password_instructions, params: { id: user.id } }

    it 'sends the Devise instructions' do
      expect { subject }.to have_enqueued_mail(DeviseUserMailer, :reset_password_instructions)
      expect(flash[:notice]).to eq("L’email de réinitialisation du mot de passe a été renvoyé.")
    end

    context 'when the administrateur must use ProConnect' do
      before do
        allow(ProConnectService).to receive(:enabled?).and_return(true)
        user.administrateur.update!(pro_connect_required_at: Time.zone.now)
      end

      it 'sends the ProConnect invitation' do
        expect { subject }.to have_enqueued_mail(UserMailer, :reset_password_via_pro_connect)
        expect(flash[:notice]).to eq("L’email d’invitation à se connecter avec ProConnect a été envoyé.")
      end
    end
  end

  describe '#update' do
    let(:super_admin) { create(:super_admin, :with_otp) }
    let(:user) { create(:user, email: 'ancien.email@domaine.fr', password: '{My-$3cure-p4ssWord}') }
    let(:otp_attempt) { current_otp_for(super_admin) }
    let(:nouvel_email) { 'nouvel.email@domaine.fr' }

    subject { patch :update, params: { id: user.id, user: { email: nouvel_email }, otp_attempt: otp_attempt } }

    it_behaves_like "a manager action gated by a fresh super-admin OTP" do
      let(:action_matcher) { change { user.reload.email } }
      let(:replay_subject) do
        -> { patch :update, params: { id: user.id, user: { email: 'second.email@domaine.fr' }, otp_attempt: otp_attempt } }
      end
    end

    context 'when the targeted email does not exist' do
      describe 'with a valid email' do
        it 'updates the user email' do
          subject

          expect(User.find_by(id: user.id).email).to eq(nouvel_email)
          expect(response).to redirect_to(edit_manager_user_path(user))
        end
      end

      describe 'with an invalid email' do
        let(:nouvel_email) { 'plop' }

        it 'does not update the user email' do
          subject

          expect(User.find_by(id: user.id).email).not_to eq(nouvel_email)
          expect(flash[:error]).to match("Le champ « Adresse électronique » est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com")
        end
      end
    end

    context 'when the targeted email exists' do
      let(:targeted_user) { create(:user, email: 'email.existant@domaine.fr', password: '{My-$3cure-p4ssWord}') }
      let(:nouvel_email) { targeted_user.email }

      it 'launches the merge process' do
        expect_any_instance_of(User).to receive(:merge).with(user)

        subject

        expect(flash[:notice]).to match("Le compte « email.existant@domaine.fr » a absorbé le compte « ancien.email@domaine.fr ».")
        expect(response).to redirect_to(edit_manager_user_path(targeted_user))
      end
    end
  end

  describe '#edit' do
    render_views

    let(:user) { create(:user) }

    it 'renders the OTP step-up input alongside the email field' do
      get :edit, params: { id: user.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="otp_attempt"')
    end
  end

  describe '#delete_edit' do
    render_views

    let(:user) { users.usager }

    it 'renders the confirmation page posting to the deletion' do
      get :delete_edit, params: { id: user.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email)
      expect(response.body).to include("action=\"#{delete_manager_user_path(user)}\"")
    end
  end

  describe '#delete' do
    let(:super_admin) { create(:super_admin, :with_otp) }
    let(:otp_attempt) { current_otp_for(super_admin) }
    let(:user) { create(:user) }

    subject { delete :delete, params: { id: user.id, otp_attempt: } }

    it_behaves_like "a manager action gated by a fresh super-admin OTP" do
      let(:other_user) { create(:user) }
      let(:action_matcher) { change { User.where(id: [user.id, other_user.id]).count } }
      let(:replay_subject) { -> { delete :delete, params: { id: other_user.id, otp_attempt: } } }
    end

    it 'deletes the user' do
      subject

      expect(User.find_by(id: user.id)).to be_nil
    end
  end

  describe '#enable_feature' do
    let(:user) { create(:user) }

    subject do
      put :enable_feature, params: { id: user.id, features: features }
    end

    before do
      Flipper.add(:administrateur_web_hook)
      Flipper.add(:arbitrary_unrelated_flag)
    end

    context 'with an allow-listed feature key' do
      let(:features) { { administrateur_web_hook: "true" } }

      it 'enables the flag for the user' do
        subject
        expect(Flipper.enabled?(:administrateur_web_hook, user)).to be true
      end
    end

    context 'with a key outside the administrateur allow-list' do
      let(:features) { { arbitrary_unrelated_flag: "true" } }

      it 'ignores the key' do
        subject
        expect(Flipper.enabled?(:arbitrary_unrelated_flag, user)).to be false
      end
    end
  end

  describe '#reactivate' do
    subject { put :reactivate, params: { id: user.id } }

    context 'when user is blocked' do
      let(:user) { create(:user, blocked_at: Time.zone.now, blocked_reason: "Activité suspecte") }

      it 'clears blocked_at and blocked_reason' do
        subject
        user.reload

        expect(user.blocked_at).to be_nil
        expect(user.blocked_reason).to be_nil
      end

      it 'enqueues a reactivation email to the user' do
        expect { subject }.to have_enqueued_mail(UserMailer, :account_reactivated).with(user)
      end

      it 'redirects to user show page with confirmation flash' do
        subject

        expect(flash[:notice]).to include("réactivé")
        expect(response).to redirect_to(manager_user_path(user))
      end
    end

    context 'when user is not blocked' do
      let(:user) { create(:user, blocked_at: nil) }

      it 'does not enqueue a reactivation email' do
        expect { subject }.not_to have_enqueued_mail(UserMailer, :account_reactivated)
      end

      it 'sets an informational flash message' do
        subject

        expect(flash[:notice]).to include("n'est pas bloqué")
      end
    end
  end
end
