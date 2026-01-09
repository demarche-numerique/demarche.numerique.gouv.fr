# frozen_string_literal: true

RSpec.describe DossierMailer, type: :mailer do
  let(:to_email) { 'instructeur@exemple.gouv.fr' }

  shared_examples 'a dossier notification' do
    it 'is sent from a no-reply address' do
      expect(subject.from.first).to eq(Mail::Address.new(NO_REPLY_EMAIL).address)
    end

    it 'includes the contact informations in the footer' do
      expect(subject.body).to include('ne pas répondre')
    end
  end

  describe '.notify_new_draft' do
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, procedure: create(:simple_procedure, :with_auto_archive), user:) }

    subject { described_class.with(dossier:).notify_new_draft }

    it 'includes the correct subject and body content' do
      expect(subject.subject).to include("brouillon")
      expect(subject.subject).to include(dossier.procedure.libelle)
      expect(subject.body).to include(dossier.procedure.libelle)
      expect(subject.body).to include(dossier_url(dossier))
      expect(subject.body).to include("Vous pouvez déposer votre dossier jusqu’au")
      expect(subject.body).to include("heure de")
    end

    it_behaves_like 'a dossier notification'

    it 'when dossier is hidden, it does not send the email' do
      dossier.hide_and_keep_track!(user, :user_request)
      expect(subject.subject).to be_nil
    end

    context 'when dossier is not brouillon anymore' do
      let(:dossier) { create(:dossier, :en_construction, user:) }

      it 'does not send the email' do
        expect(subject.subject).to be_nil
      end
    end
  end

  describe '.notify_new_answer with dossier brouillon' do
    let(:service) { build(:service) }
    let(:procedure) { create(:simple_procedure, service: service) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:commentaire) { create(:commentaire, dossier: dossier) }
    subject { described_class.with(commentaire: commentaire).notify_new_answer }

    it 'checks email subject and body for correct inclusions and exclusions' do
      expect(subject.subject).to include("Nouveau message")
      expect(subject.subject).to include(dossier.id.to_s)
      expect(subject.body).to include(dossier.procedure.service.email)
      expect(subject.body).not_to include(messagerie_dossier_url(dossier))
    end

    it_behaves_like 'a dossier notification'

    context 'when there is no associated service' do
      let(:service) { nil }
      it { expect { subject }.not_to raise_error }
    end
  end

  describe '.notify_new_answer with dossier en construction' do
    let(:dossier) { create(:dossier, :en_construction, procedure: create(:simple_procedure)) }
    let(:commentaire) { create(:commentaire, dossier: dossier) }

    subject { described_class.with(commentaire: commentaire).notify_new_answer }

    it 'checks email subject and body for correct inclusions' do
      expect(subject.subject).to include("Nouveau message")
      expect(subject.subject).to include(dossier.id.to_s)
      expect(subject.body).to include(messagerie_dossier_url(dossier))
    end

    it_behaves_like 'a dossier notification'
  end

  describe '.notify_new_answer with commentaire discarded' do
    let(:dossier) { create(:dossier, procedure: create(:simple_procedure)) }
    let(:commentaire) { create(:commentaire, dossier: dossier, discarded_at: 2.minutes.ago) }

    subject { described_class.with(commentaire: commentaire).notify_new_answer }

    it { expect(subject.perform_deliveries).to be_falsy }
  end

  describe '.notify_en_construction_deletion_to_administration' do
    let(:hidden_dossier) { build(:dossier) }

    subject { described_class.notify_en_construction_deletion_to_administration(hidden_dossier, to_email) }

    it 'verifies subject and body content for deletion notification' do
      expect(subject.subject).to eq("Le dossier n° #{hidden_dossier.id} a été supprimé à la demande de l’usager")
      expect(subject.body).to include("À la demande de l’usager")
      expect(subject.body).to include(hidden_dossier.id)
      expect(subject.body).to include(hidden_dossier.procedure.libelle)
    end
  end

  describe '.notify_brouillon_near_deletion' do
    let(:dossier) { create(:dossier) }

    subject { described_class.notify_brouillon_near_deletion([dossier], dossier.user.email) }

    it 'checks email body for correct inclusions regarding brouillon nearing deletion' do
      expect(subject.body).to include("n° #{dossier.id} ")
      expect(subject.body).to include(dossier.procedure.libelle)
      expect(subject.body).to include(I18n.l(Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now.to_date, format: :long).to_s)
    end
  end

  describe '.notify_brouillon_deletion' do
    let(:dossier) { create(:dossier) }

    subject { described_class.notify_brouillon_deletion([dossier.hash_for_deletion_mail], dossier.user.email) }

    it 'verifies subject and body content for brouillon deletion notification' do
      expect(subject.subject).to eq("Un dossier en brouillon a été supprimé")
      expect(subject.body).to include("n° #{dossier.id}")
      expect(subject.body).to include(dossier.procedure.libelle)
      expect(subject.body).to include(commencer_url(dossier.procedure.path))
    end
  end

  describe '.notify_automatic_deletion_to_user' do
    describe 'en_construction' do
      let(:hidden_dossier) { create(:dossier, :en_construction, hidden_by_expired_at: Time.zone.now, hidden_by_reason: 'expired') }

      subject { described_class.notify_automatic_deletion_to_user([hidden_dossier], hidden_dossier.user.email) }

      it 'checks email subject, to, and body for correct inclusions and exclusions for en_construction status' do
        expect(subject.to).to eq([hidden_dossier.user.email])
        expect(subject.subject).to eq("Un dossier de votre compte a été mis à la corbeille")
        expect(subject.body).to include("N° #{hidden_dossier.id} ")
        expect(subject.body).to include(hidden_dossier.procedure.libelle)
        expect(subject.body).to include(I18n.l(Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks.from_now.to_date, format: :long).to_s)
      end
    end

    describe 'termine' do
      let(:hidden_dossier) { create(:dossier, :accepte, hidden_by_expired_at: Time.zone.now, hidden_by_reason: 'expired') }

      subject { described_class.notify_automatic_deletion_to_user([hidden_dossier], hidden_dossier.user.email) }

      it 'checks email subject, to, and body for correct inclusions and exclusions for termine status' do
        expect(subject.to).to eq([hidden_dossier.user.email])
        expect(subject.subject).to eq("Un dossier de votre compte a été mis à la corbeille")
        expect(subject.body).to include("N° #{hidden_dossier.id} ")
        expect(subject.body).to include(hidden_dossier.procedure.libelle)
        expect(subject.body).to include(I18n.l(Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks.from_now.to_date, format: :long).to_s)
      end
    end
  end

  describe '.notify_automatic_deletion_to_administration' do
    let(:hidden_dossier) { create(:dossier, :accepte, hidden_by_expired_at: Time.zone.now, hidden_by_reason: 'expired') }

    subject { described_class.notify_automatic_deletion_to_administration([hidden_dossier], hidden_dossier.user.email) }

    it 'verifies subject and body content for automatic deletion notification' do
      expect(subject.subject).to eq("Un dossier a été mis à la corbeille")
      expect(subject.body).to include("n° #{hidden_dossier.id} (#{hidden_dossier.procedure.libelle})")
      expect(subject.body).to include(I18n.l(Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks.from_now.to_date, format: :long).to_s)
    end
  end

  describe '.notify_near_deletion_to_administration' do
    describe 'en_construction' do
      let(:dossier) { create(:dossier, :en_construction) }

      subject { described_class.notify_near_deletion_to_administration([dossier], dossier.user.email) }

      it 'checks email subject and body for correct inclusions for en_construction status' do
        expect(subject.subject).to eq("Un dossier en attente d’instruction va bientôt être supprimé")
        expect(subject.body).to include("N° #{dossier.id} ")
        expect(subject.body).to include(dossier.procedure.libelle)
        expect(subject.body).to include("PDF")
        expect(subject.body).to include(I18n.l(Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now.to_date, format: :long).to_s)
      end
    end

    describe 'termine' do
      let(:dossier) { create(:dossier, :accepte) }

      subject { described_class.notify_near_deletion_to_administration([dossier], dossier.user.email) }

      it 'verifies subject and body content for near deletion notification of completed cases' do
        expect(subject.subject).to eq("Un dossier traité va bientôt être supprimé")
        expect(subject.body).to include("N° #{dossier.id} ")
        expect(subject.body).to include(dossier.procedure.libelle)
        expect(subject.body).to include(I18n.l(Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now.to_date, format: :long).to_s)
      end
    end
  end

  describe '.notify_near_deletion_to_user' do
    describe 'en_construction' do
      let(:dossier) { create(:dossier, :en_construction) }

      subject { described_class.notify_near_deletion_to_user([dossier], dossier.user.email) }

      it 'verifies email subject, to, and body for correct inclusions for en_construction status' do
        expect(subject.to).to eq([dossier.user.email])
        expect(subject.subject).to eq("Un dossier en attente d’instruction va bientôt être supprimé")
        expect(subject.body).to include("N° #{dossier.id} ")
        expect(subject.body).to include(dossier.procedure.libelle)
        expect(subject.body).to include("Votre compte reste activé")
        expect(subject.body).to include("Depuis la page de votre dossier vous avez la possibilité de :<br>- prolonger la durée de conservation")
        expect(subject.body).to include(I18n.l(Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now.to_date, format: :long).to_s)
      end
    end

    describe 'termine' do
      let(:dossier) { create(:dossier, :accepte) }

      subject { described_class.notify_near_deletion_to_user([dossier], dossier.user.email) }

      it 'checks email subject, to, and body for correct inclusions for termine status' do
        expect(subject.to).to eq([dossier.user.email])
        expect(subject.subject).to eq("Un dossier traité va bientôt être supprimé")
        expect(subject.body).to include("N° #{dossier.id} ")
        expect(subject.body).to include(dossier.procedure.libelle)
        expect(subject.body).to include("Votre compte reste activé")
        expect(subject.body).to include("PDF")
        expect(subject.body).to include(I18n.l(Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now.to_date, format: :long).to_s)
      end
    end

    describe 'multiple termines' do
      let(:dossiers) { create_list(:dossier, 3, :accepte) }

      subject { described_class.notify_near_deletion_to_user(dossiers, dossiers[0].user.email) }

      it 'verifies email subject and body contain correct dossier numbers for multiple termine status' do
        expect(subject.subject).to eq("Des dossiers traités vont bientôt être supprimés")
        dossiers.each do |dossier|
          expect(subject.body).to include("N° #{dossier.id} ")
        end
      end
    end
  end

  describe '.notify_groupe_instructeur_changed_to_instructeur' do
    let(:dossier) { create(:dossier) }
    let(:instructeur) { create(:instructeur) }

    subject { described_class.notify_groupe_instructeur_changed(instructeur, dossier) }

    it 'verifies subject and body content for groupe instructeur change notification' do
      expect(subject.subject).to eq("Le dossier n° #{dossier.id} a changé de groupe d’instructeurs")
      expect(subject.body).to include("n° #{dossier.id}")
      expect(subject.body).to include(dossier.procedure.libelle)
      expect(subject.body).to include("plus accès à ce dossier.")
    end
  end

  describe '.notify_pending_correction' do
    let(:procedure) { create(:procedure) }
    let(:dossier) { create(:dossier, :en_construction, procedure:, sva_svr_decision_on:) }
    let(:sva_svr_decision_on) { nil }
    let(:reason) { :incorrect }
    let(:commentaire) { create(:commentaire, dossier:) }

    subject {
      dossier.flag_as_pending_correction!(commentaire, reason)
      described_class.with(commentaire:).notify_pending_correction
    }

    context 'reason is incorrect' do
      it 'checks email subject and body for corrections without Silence Vaut Accord' do
        expect(subject.subject).to eq("Vous devez corriger votre dossier n° #{dossier.id} « #{dossier.procedure.libelle} »")
        expect(subject.body).to include("apporter des corrections")
        expect(subject.body).not_to include("Silence")
      end
    end

    context 'sva with reason is incorrect' do
      let(:sva_svr_decision_on) { Date.tomorrow }
      let(:procedure) { create(:procedure, :sva) }

      it 'includes Silence Vaut Accord and mentions suspension for incorrect reason' do
        expect(subject.subject).to eq("Vous devez corriger votre dossier n° #{dossier.id} « #{dossier.procedure.libelle} »")
        expect(subject.body).to include("apporter des corrections")
        expect(subject.body).to include("Silence Vaut Accord")
        expect(subject.body).to include("suspendu")
      end
    end

    context 'sva with reason is incomplete' do
      let(:sva_svr_decision_on) { Date.tomorrow }
      let(:reason) { :incomplete }
      let(:procedure) { create(:procedure, :sva) }

      it 'mentions the need to complete the dossier and includes Silence Vaut Accord with reset message' do
        expect(subject.body).to include("compléter")
        expect(subject.body).to include("Silence Vaut Accord")
        expect(subject.body).to include("réinitialisé")
      end
    end

    context 'svr with reason is incomplete' do
      let(:sva_svr_decision_on) { Date.tomorrow }
      let(:reason) { :incomplete }
      let(:procedure) { create(:procedure, :svr) }

      it 'mentions the need to complete the dossier and includes Silence Vaut Rejet with reset message' do
        expect(subject.body).to include("compléter")
        expect(subject.body).to include("Silence Vaut Rejet")
        expect(subject.body).to include("réinitialisé")
      end
    end
  end

  describe 'notify_transfer' do
    let(:user) { create(:user) }
    let(:user_2) { create(:user) }
    let(:procedure) { create(:procedure) }
    let(:dossier_transfer) { create(:dossier_transfer) }
    let!(:dossier) { create(:dossier, user: user, transfer: dossier_transfer, procedure: procedure) }

    subject { described_class.with(dossier_transfer: dossier_transfer).notify_transfer }

    context 'when it is a transfer of one dossier' do
      it 'includes relevant details about the single dossier transfer request' do
        expect(subject.subject).to include("Vous avez une demande de transfert en attente.")
        expect(subject.body).to include("#{user.email} vous adresse une demande de transfert pour le dossier n° #{dossier.id} sur la démarche")
        expect(subject.body).to include(procedure.libelle.to_s)
      end
    end

    context 'when user was not validated' do
      let(:user) { create(:user, email_verified_at: nil) }

      it { expect(subject['BYPASS_UNVERIFIED_MAIL_PROTECTION']).to be_present }
    end

    context 'when the user has already an account' do
      before do
        dossier_transfer.update!(email: user_2.email)
      end
      it 'includes a direct URL to transfers' do
        expect(subject.body).to include('Afin de pouvoir accepter ou refuser la demande vous devez vous connectez sur')
        expect(subject.body).to include(dossiers_url(statut: 'dossiers-transferes'))
      end
    end

    context 'when the user has no account' do
      it 'includes a URL to create one' do
        expect(subject.body).to include('Afin de pouvoir accepter ou refuser la demande vous devez avoir un compte :')
        expect(subject.body).to include(new_user_registration_url)
      end
    end

    context 'when it is a transfer of multiple dossiers' do
      let!(:dossier2) { create(:dossier, user: user, transfer: dossier_transfer, procedure: procedure) }
      it 'includes a summary of multiple dossiers transfer request' do
        expect(subject.subject).to include("Vous avez une demande de transfert en attente.")
        expect(subject.body).to include("#{user.email} vous adresse une demande de transfert pour 2 dossiers.")
      end
    end

    context 'when it is a transfer of one dossier from super admin' do
      before do
        dossier_transfer.update!(from_support: true)
      end

      it 'includes details indicating the transfer request is from support' do
        expect(subject.subject).to include("Vous avez une demande de transfert en attente.")
        expect(subject.body).to include("Le support technique vous adresse une demande de transfert")
      end
    end

    context 'when dossiers have been dissociated from transfer' do
      before do
        dossier.update!(transfer: nil)
        dossier_transfer.reload
      end

      it 'does not send an email' do
        expect { subject.perform_now }.not_to raise_error
      end
    end
  end
end
