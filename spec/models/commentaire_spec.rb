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
        commentaire.save
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

      it { expect(commentaire.soft_deletable?(instructeur)).to be false }
    end

    context 'when a cancelled correction is attached' do
      before { create(:dossier_correction, commentaire: commentaire, dossier: dossier, cancelled_at: Time.current, resolved_at: Time.current) }

      it { expect(commentaire.soft_deletable?(instructeur)).to be true }
    end

    context 'when the message is already discarded' do
      before { commentaire.update!(discarded_at: Time.current) }

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
end
