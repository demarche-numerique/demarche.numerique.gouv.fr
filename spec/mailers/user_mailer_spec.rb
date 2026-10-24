# frozen_string_literal: true

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:user) }

  describe '.new_account_warning' do
    subject { described_class.new_account_warning(user) }

    it 'sends email to the correct user with expected body content and link' do
      expect(subject.to).to eq([user.email])
      expect(subject.body).to include(user.email)
      expect(subject.body).to have_link('Demander un nouveau mot de passe')
    end

    context 'when a procedure is provided' do
      let(:procedure) { create(:procedure) }

      subject { described_class.new_account_warning(user, procedure) }

      it { expect(subject.body).to have_link("Commencer la démarche « #{procedure.libelle} »", href: commencer_sign_in_url(path: procedure.path)) }
    end

    context 'without SafeMailer configured' do
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(nil) }
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

  describe '.ask_for_merge' do
    let(:requested_email) { 'new@exemple.fr' }

    subject { described_class.ask_for_merge(user, requested_email) }

    it 'correctly addresses the email and includes the requested email in the body' do
      expect(subject.to).to eq([requested_email])
      expect(subject.body).to include(requested_email)
    end

    context 'without SafeMailer configured' do
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(nil) }
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

  describe '.france_connect_merge_confirmation' do
    let(:email) { 'new@exemple.fr' }
    let(:code) { '123456' }

    subject { described_class.france_connect_merge_confirmation(email, code, 15.minutes.from_now) }

    it 'sends to correct email with merge link' do
      expect(subject.to).to eq([email])
      expect(subject.body).to include(france_connect_merge_using_email_link_url(email_merge_token: code))
    end

    context 'without SafeMailer configured' do
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(nil) }
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

  describe '#custom_confirmation_instructions' do
    let(:user) { create(:user, email: 'user@example.com') }
    let(:token) { 'confirmation_token_123' }
    let(:mail) { UserMailer.custom_confirmation_instructions(user, token) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Confirmez votre adresse électronique')
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['contact@demarche.numerique.gouv.fr'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(user.email)
      expect(mail.body.encoded).to match(token)
    end

    it 'assigns @user' do
      expect(mail.body.encoded).to match(user.email)
    end

    it 'assigns @token' do
      expect(mail.body.encoded).to include(token)
    end
  end

  describe '.send_archive' do
    let(:procedure) { create(:procedure) }
    let(:archive) { create(:archive) }
    subject { described_class.send_archive(role, procedure, archive) }

    context 'instructeur' do
      let(:role) { create(:instructeur) }
      it 'sends email with correct links to instructeur' do
        expect(subject.to).to eq([role.user.email])
        expect(subject.body).to have_link('Consulter mes archives', href: list_instructeur_archives_url(procedure))
        expect(subject.body).to have_link("#{procedure.id} − #{procedure.libelle}", href: instructeur_procedure_url(procedure))
      end
    end

    context 'administrateur' do
      let(:role) { administrateurs.default }
      it 'sends email with correct links to administrateur' do
        expect(subject.to).to eq([role.user.email])
        expect(subject.body).to have_link('Consulter mes archives', href: admin_procedure_archives_url(procedure))
        expect(subject.body).to have_link("#{procedure.id} − #{procedure.libelle}", href: admin_procedure_url(procedure))
      end
    end

    context 'when perform_later is called' do
      let(:role) { administrateurs.default }
      let(:custom_queue) { 'default' }
      it 'enqueues email is custom queue for non critical delivery' do
        expect { subject.deliver_later }.to have_enqueued_job.on_queue(custom_queue)
      end
    end
  end

  describe '.notify_inactive_close_to_deletion' do
    subject { described_class.notify_inactive_close_to_deletion(user) }

    let(:body) { Capybara.string(subject.body.to_s) }

    it 'says which account is deleted and how to keep it' do
      expect(subject.to).to eq([user.email])
      expect(subject.subject).to eq("Votre compte Démarche Numérique sera supprimé dans 2 semaines")
      expect(body).to have_text("à votre compte #{ApplicationController.helpers.application_name_without_link} avec l’adresse #{user.email}", normalize_ws: true)
      expect(body).to have_text("Vous n’avez plus de dossier sur la plateforme.")
      expect(body).to have_link("Conserver mon compte #{APPLICATION_NAME}", href: new_user_session_url)
      expect(body).to have_text("Vous ne souhaitez pas conserver votre compte ?")
    end

    context 'when the user has processed dossiers' do
      let(:user) { dossiers.accepte.user }

      it 'reassures about the dossiers kept by the administration' do
        expect(body).not_to have_text("Vous n’avez plus de dossier")
        expect(body).to have_text("vos dossiers traités sont conservés par l’administration", normalize_ws: true)
      end
    end

    context 'when perform_later is called' do
      let(:custom_queue) { 'default' }
      it 'enqueues email is custom queue for non critical delivery' do
        expect { subject.deliver_later }.to have_enqueued_job.on_queue(custom_queue)
      end
    end
  end

  describe '.notify_after_closing' do
    let(:procedure) { create(:procedure) }
    let(:content) { "Bonjour,\r\nsaut de ligne" }
    subject { described_class.notify_after_closing(user, content, procedure) }

    it 'notifies user about procedure closing with detailed message' do
      expect(subject.to).to eq([user.email])
      expect(subject.body).to include("Clôture d’une démarche sur #{APPLICATION_NAME}")
      expect(subject.body).to include("Bonjour,\n<br />saut de ligne")
    end

    context 'when perform_later is called' do
      let(:custom_queue) { 'default' }
      it 'enqueues email is custom queue for non critical delivery' do
        expect { subject.deliver_later }.to have_enqueued_job.on_queue(custom_queue)
      end
    end
  end

  describe '.invite_instructeur' do
    subject { described_class.invite_instructeur(user, "reset_token") }

    it { expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present }
  end

  describe '.invite_gestionnaire' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }
    subject { described_class.invite_gestionnaire(user, "reset_token", groupe_gestionnaire) }

    it { expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present }
  end

  describe '.invite_gestionnaire_via_pro_connect' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }
    subject { described_class.invite_gestionnaire_via_pro_connect(user, groupe_gestionnaire) }

    it do
      expect(subject.body).to include(groupe_gestionnaire.name)
      expect(subject.body).to include(pro_connect_url(force_pro_connect: true))
      expect(subject.body).not_to include('token=')
      expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present
    end
  end

  describe '.reset_password_via_pro_connect' do
    subject { described_class.reset_password_via_pro_connect(user) }

    it do
      expect(subject.to).to eq([user.email])
      expect(subject.body).to include(pro_connect_url(force_pro_connect: true))
      expect(subject.body).not_to include('reset_password_token=')
      expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present
    end
  end

  describe '.account_reactivated' do
    subject { described_class.account_reactivated(user) }

    it 'sends reactivation notification to user with login link' do
      expect(subject.to).to eq([user.email])
      expect(subject.body).to include(user.email)
      expect(subject.body).to have_link('Se connecter', href: new_user_session_url)
    end
  end

  describe '.password_changed' do
    subject { described_class.password_changed(user) }

    it 'sends a security notification to the user' do
      expect(subject.to).to eq([user.email])
      expect(subject.subject).to eq('Le mot de passe de votre compte a été modifié')
      expect(subject.body).to include(user.email)
      expect(subject.body).to have_link('Demander un nouveau mot de passe')
      expect(subject.body).to have_link('formulaire de contact', href: contact_url)
      expect(subject.body).to have_link(CONTACT_EMAIL, href: "mailto:#{CONTACT_EMAIL}")
    end

    it 'is a critical email' do
      expect(described_class.critical_email?('password_changed')).to be true
    end
  end
end
