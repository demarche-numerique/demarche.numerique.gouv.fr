# frozen_string_literal: true

RSpec.describe AdministrateurMailer, type: :mailer do
  let(:procedure) { create(:procedure) }
  let(:admin_email) { 'administrateur@email.fr' }

  describe '.activate_before_expiration' do
    let(:user) { create(:user, reset_password_sent_at: 2.days.ago) }
    let(:token) { SecureRandom.hex }
    subject { described_class.activate_before_expiration(user, token) }

    it "renders the body in the recipient's locale" do
      expect(subject.body).to include("Votre compte a été créé mais reste inactif")
      expect(subject.body).to include("users/activate?token=#{token}")
      user.update!(locale: 'en')
      body = described_class.activate_before_expiration(user, token).body
      expect(body).to include("still inactive")
      expect(body).not_to include("translation_missing")
    end

    context 'without SafeMailer configured' do
      it do
        expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(nil)
        expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present
      end
    end

    context 'with SafeMailer configured' do
      let(:forced_delivery_method) { :kikoo }
      before { allow(SafeMailer).to receive(:forced_delivery_method).and_return(forced_delivery_method) }
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(forced_delivery_method.to_s) }
    end

    context 'when perform_later is called' do
      it 'enqueues email in default queue for high priority delivery' do
  expect { subject.deliver_later }.to have_enqueued_job.on_queue(Rails.application.config.action_mailer.deliver_later_queue_name)
end
    end
  end

  describe '.api_entreprise_token_expiration' do
    let(:administrateur) { create(:administrateur) }
    let(:token) { JWT.encode({ exp: 2.weeks.from_now.to_i }, nil, 'none') }
    let(:procedure) { create(:procedure, administrateurs: [administrateur], api_entreprise_token: token) }

    subject { described_class.api_entreprise_token_expiration(administrateur, procedure) }

    it do
      expect(subject.to).to eq([administrateur.user.email])
      expect(subject.subject).to include("[Action requise]")
      expect(subject.subject).to include("nº#{procedure.id}")
      expect(subject.body).to include(procedure.libelle)
      expect(subject.body).to include("empêcher la création")
    end
  end

  describe '.notify_service_without_siret' do
    subject { described_class.notify_service_without_siret(admin_email) }

    it do
      expect(subject.to).to eq([admin_email])
      expect(subject.subject).to eq("SIRET manquant sur un de vos services")
      expect(subject.body).to include("un de vos services n’a pas son SIRET renseigné")
    end

    it "renders the body in the locale of the admin's account" do
      create(:user, email: admin_email, locale: 'en')
      expect(subject.body).to include("has no SIRET number")
    end

    context 'when perform_later is called' do
      let(:custom_queue) { 'default' }
      it 'enqueues email is custom queue for non critical delivery' do
        expect { subject.deliver_later }.to have_enqueued_job.on_queue(custom_queue)
      end
    end
  end
end
