# frozen_string_literal: true

RSpec.describe AdministrationMailer, type: :mailer do
  describe '#invite_admin' do
    let(:admin_user) { build(:user, last_sign_in_at: last_sign_in_at) }
    let(:token) { "some_token" }
    let(:last_sign_in_at) { nil }

    subject { described_class.invite_admin(admin_user, token) }

    it { expect(subject.subject).not_to be_empty }

    it 'renders the French body' do
      body = subject.body.decoded.squish
      expect(body).to include("Activation du compte administrateur")
      expect(body).to include("Je vous remercie de l’intérêt que vous portez à notre outil de dématérialisation de démarches.")
      expect(body).to include("Votre compte administrateur a été créé pour l’adresse électronique #{admin_user.email}.")
      expect(body).to include("Équipe de #{APPLICATION_NAME}")
    end

    it 'renders in the recipient locale, not the sender one' do
      expect(I18n.with_locale(:en) { described_class.invite_admin(admin_user, token).subject }).to eq("Activez votre compte administrateur")
    end

    context 'when the recipient uses English' do
      before { admin_user.locale = 'en' }

      it 'renders the English body' do
        expect(subject.subject).to eq("Activate your administrator account")
        body = subject.body.decoded.squish
        expect(body).to include("Your administrator account has been created for the email address #{admin_user.email}.")
        expect(body).to include("To activate it, click the following link:")
      end
    end

    describe "when the user has not been activated" do
      it do
        expect(subject.body.decoded).to include("Pour l’activer, cliquez sur le lien suivant\u00A0:")
        expect(subject.body).to include(users_activate_path(token: token))
        expect(subject.body).not_to include(edit_user_password_url(reset_password_token: token))
        expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present
      end
    end

    describe "when the user is already active" do
      let(:admin_user) { create(:user, last_sign_in_at: Time.zone.now) }
      it do
        expect(subject.body.decoded).to include("Pour vous connecter, cliquez sur le lien suivant\u00A0:")
        expect(subject.body).not_to include(users_activate_path(token: token))
        expect(subject.body).to include(%(href="#{edit_user_password_url(reset_password_token: token)}"))
      end
    end
  end

  describe '#invite_admin_via_pro_connect' do
    let(:admin_user) { create(:user) }

    subject { described_class.invite_admin_via_pro_connect(admin_user) }

    it do
      expect(subject.subject).to eq("Activez votre compte administrateur")
      expect(subject.body).to include(pro_connect_url(force_pro_connect: true))
      expect(subject.body).not_to include('token=')
      expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present
    end

    it 'renders the French body' do
      body = subject.body.decoded.squish
      expect(body).to include("Activation du compte administrateur")
      expect(body).to include("Votre compte administrateur a été créé pour l’adresse électronique #{admin_user.email}.")
      expect(subject.body.decoded).to include("Pour l’activer, connectez-vous avec ProConnect en utilisant cette même adresse électronique :")
    end

    it 'renders in the recipient locale, not the sender one' do
      expect(I18n.with_locale(:en) { described_class.invite_admin_via_pro_connect(admin_user).subject }).to eq("Activez votre compte administrateur")
    end

    context 'when the recipient uses English' do
      let(:admin_user) { create(:user, locale: 'en') }

      it 'renders the English body' do
        expect(subject.subject).to eq("Activate your administrator account")
        body = subject.body.decoded.squish
        expect(body).to include("Your administrator account has been created for the email address #{admin_user.email}.")
        expect(body).to include("To activate it, sign in with ProConnect using this same email address:")
      end
    end
  end
end
