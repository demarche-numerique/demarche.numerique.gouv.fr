# frozen_string_literal: true

describe Commentaire do
  it do
    is_expected.to have_db_column(:email)
    is_expected.to have_db_column(:body)
    is_expected.to have_db_column(:created_at)
    is_expected.to have_db_column(:updated_at)
  end

  describe 'messagerie_available validation' do
    subject { commentaire.valid?(:create) }

    context 'with a commentaire created by the DS system' do
      let(:commentaire) { build :commentaire, email: CONTACT_EMAIL }

      it { is_expected.to be_truthy }
    end

    context 'on an archived dossier' do
      let(:dossier) { create :dossier, :archived }
      let(:commentaire) { build :commentaire, dossier: dossier }

      it { is_expected.to be_truthy }
    end

    context 'on a dossier en_construction' do
      let(:dossier) { create :dossier, :en_construction }
      let(:commentaire) { build :commentaire, dossier: dossier }

      it { is_expected.to be_truthy }
    end
  end

  describe "#sent_by_system?" do
    subject { commentaire.sent_by_system? }

    let(:commentaire) { build :commentaire, email: email }

    context 'with a commentaire created by the DS system' do
      let(:email) { CONTACT_EMAIL }

      it { is_expected.to be_truthy }
    end

    context 'with demarche.numerique.gouv.fr' do
      let(:email) { "contact@demarche.numerique.gouv.fr" }

      it { is_expected.to be_truthy }
    end

    context 'other email' do
      let(:email) { "me@spec.test" }

      it { is_expected.to be_falsey }
    end
  end

  describe "sent_by?" do
    let(:commentaire) { build(:commentaire, instructeur: build(:instructeur)) }
    subject { commentaire.sent_by?(nil) }
    it { is_expected.to be_falsy }
  end

  describe "#redacted_email" do
    subject { commentaire.redacted_email }

    let(:procedure) { create(:procedure, hide_instructeurs_email: false) }
    let(:dossier) { create(:dossier, procedure: procedure) }

    context 'with a commentaire created by a instructeur' do
      let(:instructeur) { create :instructeur, email: 'some_user@exemple.fr' }
      let(:commentaire) { build :commentaire, instructeur: instructeur, dossier: dossier }

      context 'when the procedure shows instructeurs email' do
        it { is_expected.to eq 'some_user' }
      end

      context 'when the procedure hides instructeurs email' do
        let(:procedure) { create(:procedure, hide_instructeurs_email: true) }
        it { is_expected.to eq "Instructeur n° #{instructeur.id}" }
      end
    end

    context 'with a commentaire created by a user' do
      let(:commentaire) { build :commentaire, email: user.email }
      let(:user) { build :user, email: 'some_user@exemple.fr' }

      it { is_expected.to eq 'some_user@exemple.fr' }
    end
  end

  describe "#notify" do
    let(:procedure) { create(:procedure) }
    let(:instructeur) { create(:instructeur) }
    let(:expert) { create(:expert) }
    let(:assign_to) { create(:assign_to, instructeur: instructeur, procedure: procedure) }
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure, user: user) }

    context "with a commentaire created by a instructeur" do
      let(:commentaire) { CommentaireService.build(instructeur, dossier, body: "Mon commentaire") }

      it "calls notify_user with delay so instructeur can destroy his comment in case of failure" do
        expect(commentaire).to receive(:notify_user).with(wait: 5.minutes)
        commentaire.save
      end
    end

    context "with a commentaire created by an expert" do
      let(:commentaire) { CommentaireService.build(expert, dossier, body: "Mon commentaire") }

      it "calls notify_user with delay so expert can destroy his comment in case of failure" do
        expect(commentaire).to receive(:notify_user).with(wait: 5.minutes)
        commentaire.save
      end
    end

    context "with a commentaire automatically created (notification)" do
      let(:commentaire) { CommentaireService.build(CONTACT_EMAIL, dossier, body: "Mon commentaire") }

      it "does not call notify_user" do
        expect(commentaire).not_to receive(:notify_user).with(no_args)
        expect(Ami::CreateNotificationService).not_to receive(:call)
        commentaire.save
      end
    end

    context "with a commentaire created by a user" do
      let(:commentaire) { CommentaireService.build(user, dossier, body: "Mon commentaire usager") }

      it "does not trigger AMI user notification" do
        expect(Ami::CreateNotificationService).not_to receive(:call)
        commentaire.save
      end
    end
  end

  describe "#notify_user" do
    let(:procedure) { create(:procedure) }
    let(:instructeur) { create(:instructeur) }
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :en_construction, procedure:, user: user) }
    let(:commentaire) { CommentaireService.build(instructeur, dossier, body: "Mon commentaire") }
    let(:mail_delivery) { double(deliver_later: true) }
    let(:mailer) { double(notify_pending_correction: mail_delivery, notify_new_answer: mail_delivery) }

    before do
      allow(DossierMailer).to receive(:with).with(commentaire: commentaire).and_return(mailer)
    end

    it "triggers AMI notification with messagerie trigger" do
      expect(Ami::CreateNotificationService).to receive(:call).with(dossier: dossier, trigger: :messagerie_message)

      commentaire.send(:notify_user, wait: 5.minutes)
    end

    context "when the commentaire carries a correction request" do
      before { commentaire.dossier_correction = build(:dossier_correction, dossier:, commentaire:) }

      it "triggers AMI notification with the correction trigger" do
        expect(Ami::CreateNotificationService).to receive(:call).with(dossier: dossier, trigger: :pending_correction)

        commentaire.send(:notify_user, wait: 5.minutes)
      end
    end
  end

  describe 'body validation' do
    let(:dossier) { create(:dossier, :en_construction) }

    context 'when body is blank and no piece_jointe' do
      let(:commentaire) { build(:commentaire, dossier:, body: '') }

      it { expect(commentaire).not_to be_valid }
      it { expect { commentaire.valid? }.to change { commentaire.errors[:body] }.to(["ne peut être vide"]) }
    end

    context 'when body is blank but piece_jointe is attached' do
      let(:commentaire) { build(:commentaire, dossier:, body: '') }

      before do
        commentaire.piece_jointe.attach(io: StringIO.new('fake'), filename: 'doc.pdf', content_type: 'application/pdf')
      end

      it { expect(commentaire).to be_valid }
    end

    context 'when body is present and no piece_jointe' do
      let(:commentaire) { build(:commentaire, dossier:, body: 'Hello') }

      it { expect(commentaire).to be_valid }
    end
  end

  describe 'piece_jointe size validation' do
    let(:dossier) { create(:dossier, :en_construction) }
    let(:commentaire) { build(:commentaire, dossier:, body: 'Hello') }

    before do
      commentaire.piece_jointe.attach(io: StringIO.new('fake'), filename: 'doc.pdf', content_type: 'application/pdf')
      commentaire.piece_jointe.attachments.each { it.blob.byte_size = byte_size }
      commentaire.validate
    end

    context 'when the file fits in the limit' do
      let(:byte_size) { Commentaire::FILE_MAX_SIZE - 1 }

      it { expect(commentaire.errors).not_to be_of_kind(:piece_jointe, :file_size_not_less_than) }
    end

    context 'when the file exceeds the limit' do
      let(:byte_size) { Commentaire::FILE_MAX_SIZE + 1 }

      it 'rejects the file with the maximum size message' do
        expect(commentaire.errors).to be_of_kind(:piece_jointe, :file_size_not_less_than)
        expect(commentaire.errors.messages_for(:piece_jointe)).to eq(['La taille maximale du fichier autorisée est de 200 Mo.'])
      end
    end
  end

  describe 'normalization' do
    it 'removes non-printable characters from body' do
      commentaire = build(:commentaire, body: "Valid\x00Body\x1F")
      commentaire.validate
      expect(commentaire.body).to eq("ValidBody")
    end
  end

  describe '#soft_deletable?' do
    let(:instructeur) { create(:instructeur) }
    let(:dossier) { create(:dossier, :en_construction) }
    let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }

    context 'when the message is sent by the connected user' do
      it { expect(commentaire.soft_deletable?(instructeur)).to be true }
    end

    context 'when a pending correction is attached' do
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier) }

      context 'with cancel_correction: true (default)' do
        it 'returns true' do
          expect(commentaire.soft_deletable?(instructeur)).to be true
          expect(commentaire.soft_deletable?(instructeur, cancel_correction: true)).to be true
        end
      end

      context 'with cancel_correction: false' do
        it { expect(commentaire.soft_deletable?(instructeur, cancel_correction: false)).to be false }
      end
    end

    context 'when a cancelled correction is attached' do
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier, cancelled_at: Time.current, resolved_at: Time.current) }

      it { expect(commentaire.soft_deletable?(instructeur)).to be true }
    end

    context 'when the message is already discarded' do
      before { commentaire.update!(discarded_at: Time.current) }

      it { expect(commentaire.soft_deletable?(instructeur)).to be false }
    end

    context 'when the message is not deletable' do
      before { commentaire.update!(deletable: false) }

      it { expect(commentaire.soft_deletable?(instructeur)).to be false }
    end
  end

  describe '#can_cancel_correction?' do
    let(:instructeur) { create(:instructeur) }
    let(:dossier) { create(:dossier, :en_construction) }
    let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }

    context 'when no correction is attached' do
      it { expect(commentaire.can_cancel_correction?(instructeur)).to be_falsey }
    end

    context 'when a pending correction is attached' do
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier) }

      it { expect(commentaire.can_cancel_correction?(instructeur)).to be true }
    end

    context 'when the correction is already cancelled' do
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier, cancelled_at: Time.current, resolved_at: Time.current) }

      it { expect(commentaire.can_cancel_correction?(instructeur)).to be false }
    end

    context 'when the message is discarded' do
      before do
        create(:dossier_correction, commentaire: commentaire, dossier: dossier)
        commentaire.update!(discarded_at: Time.current)
      end

      it { expect(commentaire.can_cancel_correction?(instructeur)).to be false }
    end

    context 'when the connected user is not the sender' do
      let(:other_instructeur) { create(:instructeur) }
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier) }

      it { expect(commentaire.can_cancel_correction?(other_instructeur)).to be false }
    end

    context 'when the connected user is the usager (not instructeur)' do
      let(:user) { dossier.user }
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier) }

      it { expect(commentaire.can_cancel_correction?(user)).to be false }
    end
  end

  describe '#cancel_correction!' do
    let(:instructeur) { create(:instructeur) }
    let(:dossier) { create(:dossier, :en_construction) }
    let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }
    let!(:correction) { create(:dossier_correction, commentaire: commentaire, dossier: dossier) }

    it 'cancels the correction' do
      commentaire.cancel_correction!
      expect(correction.reload).to be_cancelled
      expect(correction).to be_resolved
    end

    it 'keeps the message body' do
      original_body = commentaire.body
      commentaire.cancel_correction!
      expect(commentaire.reload.body).to eq(original_body)
    end
  end

  describe '.mark_agent_messages_as_seen' do
    let(:dossier) { create(:dossier, :en_construction) }
    let!(:instructeur_message) { create(:commentaire, dossier: dossier, instructeur: create(:instructeur), seen_by_recipient_at: nil) }
    let!(:expert_message) { create(:commentaire, dossier: dossier, expert: create(:expert), seen_by_recipient_at: nil) }
    let!(:user_message) { create(:commentaire, dossier: dossier, seen_by_recipient_at: nil) }

    before { Commentaire.mark_agent_messages_as_seen(dossier) }

    it 'marks unseen instructeur messages as seen' do
      expect(instructeur_message.reload.seen_by_recipient_at).to be_present
    end

    it 'marks unseen expert messages as seen' do
      expect(expert_message.reload.seen_by_recipient_at).to be_present
    end

    it 'leaves the user own messages untouched' do
      expect(user_message.reload.seen_by_recipient_at).to be_nil
    end
  end

  # A revoked expert keeps no access to the dossier, so the messagerie must stop
  # reaching them. The second expert's avis on the same dossier is left alone,
  # which is what keeps these assertions specific to the revoked one.
  describe 'notifying the experts of a new message' do
    before do
      experts_procedures.default.update!(notify_on_new_message: true)
      experts_procedures.second.update!(notify_on_new_message: true)
    end

    subject do
      create(:commentaire, dossier: dossiers.en_instruction, email: dossiers.en_instruction.user.email)
    end

    let(:mail_to_default_expert) do
      have_enqueued_mail(AvisMailer, :notify_new_commentaire_to_expert)
        .with(dossiers.en_instruction, avis.pending, experts.default)
    end

    # Spelled as a count rather than a `not_to`, so it can join the positive
    # expectation in a single block: `subject` is memoized, and a second
    # `expect { subject }` block enqueues nothing — it would pass whatever the
    # loop did.
    let(:no_mail_to_default_expert) do
      have_enqueued_mail(AvisMailer, :notify_new_commentaire_to_expert)
        .with(dossiers.en_instruction, avis.pending, experts.default)
        .exactly(0).times
    end

    # Asserted in every context: it is what tells a revocation apart from a
    # loop that stopped notifying anyone at all.
    let(:mail_to_second_expert) do
      have_enqueued_mail(AvisMailer, :notify_new_commentaire_to_expert)
        .with(dossiers.en_instruction, avis.confidentiel, experts.second)
    end

    it 'notifies both experts who have an avis on the dossier' do
      expect { subject }.to mail_to_default_expert.and mail_to_second_expert
    end

    context 'when the avis itself has been revoked' do
      before { avis.pending.update!(answer: 'Avis favorable', revoked_at: Time.zone.now) }

      it 'stops notifying that expert, and only that one' do
        expect { subject }.to mail_to_second_expert.and no_mail_to_default_expert
      end
    end

    context 'when the expert has been revoked from the procedure' do
      before do
        procedures.individual.update!(experts_require_administrateur_invitation: true)
        experts_procedures.default.update!(revoked_at: Time.zone.now)
      end

      it 'stops notifying that expert, and only that one' do
        expect { subject }.to mail_to_second_expert.and no_mail_to_default_expert
      end
    end
  end
end
