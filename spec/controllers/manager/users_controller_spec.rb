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

    context 'when user is blocked' do
      let(:user) { create(:user, blocked_at: Time.zone.now) }

      it 'displays the reactivate button' do
        expect(response.body).to include("Réactiver le compte")
      end
    end
  end

  describe '#update' do
    let(:user) { create(:user, email: 'ancien.email@domaine.fr', password: '{My-$3cure-p4ssWord}') }

    subject { patch :update, params: { id: user.id, user: { email: nouvel_email } } }

    context 'when the targeted email does not exist' do
      describe 'with a valid email' do
        let(:nouvel_email) { 'nouvel.email@domaine.fr' }

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

  describe '#delete' do
    let(:user) { create(:user) }

    subject { delete :delete, params: { id: user.id } }

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
