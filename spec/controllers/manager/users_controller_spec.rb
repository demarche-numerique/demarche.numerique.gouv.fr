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

      it 'explains what blocks it instead of offering the deletion' do
        expect(response.body).not_to include(delete_edit_manager_user_path(user))
        expect(response.body).to include(manager_administrateur_path(administrateurs.default))
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

    it 'loads the mails sent through the providers on demand' do
      frame = response.parsed_body.at_css('turbo-frame#user-sent-mails')

      expect(frame.to_h).to include('src' => emails_manager_user_path(user), 'loading' => 'lazy')
    end

    it 'says Brevo reported no block' do
      expect(response.parsed_body.at_css('.user-mails__reception').text).to include('Aucun blocage signalé par Brevo')
    end

    context 'when Brevo blocked the user for a spam complaint' do
      let(:user) do
        users.usager.tap { it.record_brevo_block!(at: Time.zone.parse('2026-11-03 14:00'), event: 'spam') }
      end

      it 'shows the block, its reason and the unsubscription' do
        reception = response.parsed_body.at_css('.user-mails__reception').text.squish

        expect(reception).to include('Bloquée chez Brevo depuis le 03 novembre 2026 à 14:00 (signalement comme spam)')
        expect(reception).to include('Désinscrit')
      end
    end

    context 'when we sent mails to the user' do
      let(:user) do
        create(:email_event, to: users.usager.email, subject: 'Votre dossier est accepté')
        create(:email_event, to: 'quelquun@exemple.fr', subject: 'Un autre dossier')
        users.usager
      end

      it 'lists the mails sent to its address only' do
        events = response.parsed_body.at_css('.user-mails__events').text

        expect(events).to include('Votre dossier est accepté')
        expect(events).not_to include('Un autre dossier')
      end
    end
  end

  describe '#emails' do
    render_views

    let(:user) { users.usager }
    let(:sent_mail) do
      SentMail.new(from: 'contact@exemple.fr', to: user.email, subject: 'Votre dossier', delivered_at: Time.zone.parse('2026-11-05 10:00'), status: 'delivered', service_name: 'Brevo', external_url: 'https://app.brevo.com/transactional/email/logs')
    end

    before do
      allow(Brevo::API).to receive(:new).and_return(instance_double(Brevo::API, properly_configured?: true, sent_mails: [sent_mail]))
      allow(Scaleway::API).to receive(:new).and_return(instance_double(Scaleway::API, properly_configured?: false))

      get :emails, params: { id: user.id }
    end

    it 'renders the mails in the frame of the user page, without layout' do
      frame = response.parsed_body.at_css('turbo-frame#user-sent-mails')

      expect(frame.text).to include('Votre dossier')
      expect(response.body).not_to include('main-content__header')
    end
  end

  describe '#index' do
    render_views

    let!(:user) { create(:user, email: 'camille@manager-search.test') }
    let!(:lookalike) { create(:user, email: "#{user.id}.xcamille@manager-search.test") }

    def listed_ids
      response.body.scan(%r{href="/manager/users/(\d+)"}).flatten.map(&:to_i).uniq
    end

    it 'finds the user by exact email, ignoring case and surrounding spaces' do
      get :index, params: { search: '  Camille@Manager-Search.test ' }

      expect(listed_ids).to eq([user.id])
    end

    it 'finds the user by exact id' do
      get :index, params: { search: user.id.to_s }

      expect(listed_ids).to eq([user.id])
    end

    it 'falls back to a partial search when nothing matches exactly' do
      get :index, params: { search: '@manager-search.test' }

      expect(listed_ids).to contain_exactly(user.id, lookalike.id)
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

  describe '#unblock_email' do
    let(:user) { users.usager }
    let(:brevo) { instance_double(Brevo::API, unblock_user:) }

    let(:now) { Time.zone.parse('2026-11-06 10:00') }

    before do
      allow(Brevo::API).to receive(:new).and_return(brevo)
      user.update_columns(email_unsubscribed: true)
      travel_to(now) { put :unblock_email, params: { user_id: user.id } }
    end

    context 'when Brevo unblocks the address' do
      let(:unblock_user) { true }

      it 'subscribes the user again and records the unblock' do
        expect(user.reload).to have_attributes(email_unsubscribed: false, brevo_unblocked_at: now)
        expect(response).to redirect_to(manager_user_path(user, anchor: 'emails'))
      end
    end

    context 'when Brevo refuses' do
      let(:unblock_user) { false }

      it 'keeps the user unsubscribed and records nothing' do
        expect(user.reload).to have_attributes(email_unsubscribed: true, brevo_unblocked_at: nil)
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
