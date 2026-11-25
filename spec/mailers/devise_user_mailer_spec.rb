# frozen_string_literal: true

RSpec.describe DeviseUserMailer, type: :mailer do
  let(:user) { users.usager }
  let(:token) { SecureRandom.hex }

  def text_of(body) = Capybara.string(body.to_s).text.gsub(/\s+/, " ")

  describe '.confirmation_instructions' do
    subject { described_class.confirmation_instructions(user, token, opts = {}) }

    context 'without SafeMailer configured' do
      it do
        expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(nil)
        expect(subject[BalancerDeliveryMethod::BYPASS_UNVERIFIED_MAIL_PROTECTION]).to be_present
      end
    end

    context 'with SafeMailer configured' do
      let(:forced_delivery_method) { :kikoo }
      before { allow(SafeMailer).to receive(:forced_delivery_method).and_return(forced_delivery_method) }
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(forced_delivery_method.to_s) }
    end

    context 'with a procedure and a prefill token' do
      subject { described_class.confirmation_instructions(user, token, procedure_after_confirmation: procedures.individual, prefill_token: 'prefill-token') }

      it 'keeps them out of the headers' do
        expect(subject['procedure-after-confirmation']).to be_nil
        expect(subject['prefill-token']).to be_nil
      end
    end

    context 'when perform_later is called' do
      it 'enqueues email in default queue for high priority delivery' do
        expect { subject.deliver_later }.to have_enqueued_job.on_queue(Rails.application.config.action_mailer.deliver_later_queue_name)
      end
    end

    context 'when an email change is being confirmed' do
      before { user.update_column(:unconfirmed_email, 'nouvelle@adresse.fr') }

      it 'keeps its own subject and no activation button' do
        expect(subject.subject).to eq('Instructions de confirmation')
        expect(subject.body).not_to have_link('Activer mon compte')
        expect(subject.body).to have_link(user_confirmation_url(confirmation_token: token))
      end

      it 'is translated in en' do
        user.update_column(:locale, 'en')
        expect(text_of(subject.body)).to include('To confirm your account email change, select the following link:')
      end
    end

    describe "i18n" do
      context "when locale is fr" do
        let(:user) { create(:user, locale: :fr) }

        it "uses fr locale" do
          expect(subject.subject).to eq("Activez votre compte sur #{APPLICATION_NAME}")
          expect(subject.body).to include("Activez votre compte sur #{APPLICATION_NAME}")
          expect(subject.body).to include('Pour confirmer votre adresse électronique et activer votre compte sur')
        end

        it 'puts the activation link behind a button and spells it out below' do
          link = user_confirmation_url(confirmation_token: token)
          expect(subject.body).to have_link('Activer mon compte', href: link)
          expect(text_of(subject.body)).to include("Si le bouton ci-dessus ne fonctionne pas, veuillez copier-coller le lien suivant dans votre navigateur\u00a0:")
          expect(subject.body).to have_link(link, href: link)
        end
      end

      context "when locale is en" do
        let(:user) { create(:user, locale: :en) }

        it "uses en locale" do
          expect(subject.subject).to eq("Activate your account on #{APPLICATION_NAME}")
          expect(subject.body).to include("Activate your account on #{APPLICATION_NAME}")
          expect(subject.body).to include('To confirm your email address and activate your account on')
        end

        it 'puts the activation link behind a button and spells it out below' do
          link = user_confirmation_url(confirmation_token: token)
          expect(subject.body).to have_link('Activate my account', href: link)
          expect(text_of(subject.body)).to include('If the button above does not work, copy and paste the following link into your browser:')
          expect(subject.body).to have_link(link, href: link)
        end

        it 'keeps the prefill token in the activation link' do
          mail = described_class.confirmation_instructions(user, token, prefill_token: 'prefill-token')
          expect(mail.body).to have_link('Activate my account', href: user_confirmation_url(confirmation_token: token, prefill_token: 'prefill-token'))
        end
      end
    end
  end

  describe '.email_changed' do
    subject { described_class.email_changed(user, to: user.email) }

    shared_examples 'a warning to the current address' do
      it 'names the requested address and points to the support' do
        expect(subject.to).to eq([user.email])
        expect(subject.subject).to eq('Changement de l’adresse électronique de votre compte')
        expect(subject.body).to include(requested_email)
        expect(subject.body).to have_link('formulaire de contact', href: contact_url)
        expect(subject.body).to have_link(CONTACT_EMAIL, href: "mailto:#{CONTACT_EMAIL}")
      end
    end

    context 'when a new address is waiting for confirmation' do
      let(:requested_email) { 'nouvelle@adresse.fr' }

      before { user.update_column(:unconfirmed_email, requested_email) }

      it_behaves_like 'a warning to the current address'
    end

    context 'when a merge into another account is requested' do
      let(:other_user) { create(:user) }
      let(:requested_email) { other_user.email }

      before { user.update_column(:requested_merge_into_id, other_user.id) }

      it_behaves_like 'a warning to the current address'
    end

    context 'when the change is done' do
      it 'gives the new address' do
        expect(text_of(subject.body)).to include("Vous pouvez désormais vous connecter avec l’adresse #{user.email}")
      end

      it 'is translated in en' do
        body = I18n.with_locale(:en) { described_class.email_changed(user, to: user.email).body.to_s }
        expect(text_of(body)).to include("You can now sign in with the email address #{user.email}")
        expect(body).to have_link('contact form', href: contact_url)
      end
    end
  end

  describe '.password_change' do
    it 'confirms the change in fr and en' do
      expect(text_of(described_class.password_change(user, {}).body)).to include("La demande de changement de mot de passe pour votre compte #{user.email}")
      body = I18n.with_locale(:en) { described_class.password_change(user, {}).body.to_s }
      expect(text_of(body)).to include("A request to change your password on #{APPLICATION_NAME} for the account #{user.email}")
    end
  end

  describe '.reset_password_instructions' do
    it 'links to the new password form in fr and en' do
      link = edit_user_password_url(reset_password_token: token)
      expect(described_class.reset_password_instructions(user, token).body).to have_link('Changer mon mot de passe', href: link)
      body = I18n.with_locale(:en) { described_class.reset_password_instructions(user, token).body.to_s }
      expect(body).to have_link('Change the password', href: link)
    end
  end

  describe 'locale' do
    it 'follows the recipient, not the request that enqueued the email' do
      user.update_column(:locale, 'en')
      body = I18n.with_locale(:fr) { described_class.reset_password_instructions(user, token).body.to_s }
      expect(body).to have_link('Change the password')
    end
  end

  describe '.unlock_instructions' do
    it 'links to the unlock page in fr and en' do
      link = user_unlock_url(unlock_token: token)
      expect(described_class.unlock_instructions(user, token).body).to have_link('Déverrouiller mon compte', href: link)
      body = I18n.with_locale(:en) { described_class.unlock_instructions(user, token).body.to_s }
      expect(body).to have_link('Unlock account', href: link)
    end
  end
end
