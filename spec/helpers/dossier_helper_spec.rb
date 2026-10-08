# frozen_string_literal: true

RSpec.describe DossierHelper, type: :helper do
  describe ".highlight_if_unseen_class" do
    let(:seen_at) { Time.zone.now }

    subject { highlight_if_unseen_class(seen_at, updated_at) }

    context "when commentaire date is created before last seen datetime" do
      let(:updated_at) { seen_at - 2.days }

      it { is_expected.to eq nil }
    end

    context "when commentaire date is created after last seen datetime" do
      let(:updated_at) { seen_at + 2.hours }

      it { is_expected.to eq "highlighted" }
    end

    context "when there is no last seen datetime" do
      let(:updated_at) { Time.zone.now }
      let(:seen_at) { nil }

      it { is_expected.to eq nil }
    end
  end

  describe ".url_for_dossier" do
    subject { url_for_dossier(dossier) }

    context "when the dossier is in the brouillon state" do
      let(:dossier) { dossiers.brouillon }
      it { is_expected.to eq "/dossiers/#{dossier.id}/brouillon" }
    end

    context "when the dossier is any other state" do
      let(:dossier) { dossiers.en_construction }
      it { is_expected.to eq "/dossiers/#{dossier.id}" }
    end
  end

  describe ".demandeur_dossier" do
    subject { demandeur_dossier(dossier) }

    let(:individual) { build(:individual, dossier: nil) }
    let(:etablissement) { build(:etablissement) }
    let(:dossier) { create(:dossier, procedure: procedure, individual: individual, etablissement: etablissement) }

    context "when the dossier is for an individual" do
      let(:procedure) { procedures.individual }

      context "when the individual is not provided" do
        let(:individual) { build(:individual, :empty) }
        it { is_expected.to be_blank }
      end

      context "when the individual has name information" do
        it { is_expected.to eq "#{individual.prenom} #{individual.nom}" }
      end
    end

    context "when the dossier is for a company" do
      let(:procedure) { create(:procedure, for_individual: false) }

      context "when the company is not provided" do
        let(:etablissement) { nil }
        it { is_expected.to be_blank }
      end

      context "when the company has name information" do
        it { is_expected.to eq raison_sociale_or_name(etablissement) }
      end

      context "when the company is not diffusable" do
        let(:etablissement) { build(:etablissement, :non_diffusable, siret: "12345678901234") }

        it { is_expected.to include("123 456 789 01234") }
      end
    end
  end

  describe ".dossier_submission_is_closed?" do
    subject { dossier_submission_is_closed?(dossier) }

    context "when dossier state is brouillon" do
      let(:dossier) { dossiers.brouillon }

      it { is_expected.to be false }

      context "when dossier state is brouillon and procedure is close" do
        before { dossier.procedure.close }

        it { is_expected.to be true }
      end
    end

    shared_examples_for "returns false" do
      it { is_expected.to be false }

      context "and procedure is close" do
        before { dossier.procedure.close }

        it { is_expected.to be false }
      end
    end

    context "when dossier state is en_construction" do
      let(:dossier) { dossiers.en_construction }

      it_behaves_like "returns false"
    end

    context "when dossier state is en_instruction" do
      let(:dossier) { dossiers.en_instruction }

      it_behaves_like "returns false"
    end

    context "when dossier state is accepte" do
      let(:dossier) { dossiers.accepte }

      it_behaves_like "returns false"
    end

    context "when dossier state is refuse" do
      let(:dossier) { dossiers.refuse }

      it_behaves_like "returns false"
    end

    context "when dossier state is sans_suite" do
      let(:dossier) { create(:dossier, state: Dossier.states.fetch(:sans_suite)) }

      it_behaves_like "returns false"
    end
  end

  describe '.dossier_display_state' do
    let(:dossier) { dossiers.brouillon }

    subject { dossier_display_state(dossier) }

    it 'brouillon is brouillon' do
      dossier.brouillon!
      expect(subject).to eq('Brouillon')
    end

    it 'en_construction is En construction' do
      dossier.en_construction!
      expect(subject).to eq('En construction')
    end

    it 'accepte is traité' do
      dossier.accepte!
      expect(subject).to eq('Accepté')
    end

    it 'en_instruction is reçu' do
      dossier.en_instruction!
      expect(subject).to eq('En instruction')
    end

    it 'sans_suite is traité' do
      dossier.sans_suite!
      expect(subject).to eq('Classé sans suite')
    end

    it 'refuse is traité' do
      dossier.refuse!
      expect(subject).to eq('Refusé')
    end

    context 'when requesting lowercase' do
      subject { dossier_display_state(dossier, lower: true) }

      it 'lowercases the display name' do
        dossier.brouillon!
        expect(subject).to eq('brouillon')
      end
    end

    context 'when providing directly a state name' do
      subject { dossier_display_state(:brouillon) }

      it 'generates a display name for the given state' do
        expect(subject).to eq('Brouillon')
      end
    end
  end

  describe '.dossier_legacy_state' do
    subject { dossier_legacy_state(dossier) }

    context 'when the dossier is en instruction' do
      let(:dossier) { dossiers.brouillon }

      it { is_expected.to eq('brouillon') }
    end

    context 'when the dossier is en instruction' do
      let(:dossier) { dossiers.en_instruction }

      it { is_expected.to eq('received') }
    end

    context 'when the dossier is accepte' do
      let(:dossier) { dossiers.accepte }

      it { is_expected.to eq('closed') }
    end

    context 'when the dossier is refuse' do
      let(:dossier) { dossiers.refuse }

      it { is_expected.to eq('refused') }
    end

    context 'when the dossier is sans_suite' do
      let(:dossier) { create(:dossier, state: Dossier.states.fetch(:sans_suite)) }

      it { is_expected.to eq('without_continuation') }
    end
  end

  describe ".france_connect_information" do
    subject { france_connect_informations(user_information) }

    context "with complete france_connect information" do
      let(:user_information) { build(:france_connect_information, updated_at: Time.zone.now) }
      it {
        expect(subject).to have_text("Le dossier a été déposé par le compte de #{user_information.given_name} #{user_information.family_name}, authentifié par FranceConnect.")
      }
    end

    context "with missing given_name" do
      let(:user_information) { build(:france_connect_information, given_name: nil) }

      it {
        expect(subject).to have_text("Le dossier a été déposé par le compte de #{user_information.family_name}, authentifié par FranceConnect.")
      }
    end

    context "with all names missing" do
      let(:user_information) { build(:france_connect_information, given_name: nil, family_name: nil) }

      it {
        expect(subject).to have_text("Le dossier a été déposé par un compte authentifié par FranceConnect.")
      }
    end
  end

  describe ".pro_connect_informations" do
    subject { pro_connect_informations(user_information) }

    context "with complete pro_connect information" do
      let(:user_information) { build(:pro_connect_information) }

      it {
        expect(subject).to have_text("Le dossier a été déposé par le compte de #{user_information.given_name} #{user_information.usual_name}, authentifié par ProConnect.")
      }
    end

    context "with all names missing" do
      let(:user_information) { build(:pro_connect_information, given_name: nil, usual_name: nil) }

      it {
        expect(subject).to have_text("Le dossier a été déposé par un compte authentifié par ProConnect.")
      }
    end
  end

  describe ".tags_notification" do
    subject { tags_notification([notification]) }

    context "with dossier_depose notification" do
      let(:instructeur) { instructeurs.default }
      let(:dossier) { create(:dossier, depose_at: 10.days.ago) }
      let!(:notification) { create(:dossier_notification, instructeur:, dossier:, notification_type: :dossier_depose, display_at: (dossier.depose_at + DossierNotification::DELAY_DOSSIER_DEPOSE)) }

      it {
        expect(subject).to have_text("Déposé depuis 10 J.")
      }
    end
  end

  describe ".badge_notification_text_a11y" do
    [:dossier_modifie, :message, :annotation_instructeur, :avis_externe].each do |notification_type|
      context "with a #{notification_type} notification" do
        it "announces a nouveauté" do
          expect(badge_notification_text_a11y(notification_type, summary: true)).to eq("dossiers avec au moins une nouveauté")
          expect(badge_notification_text_a11y(notification_type, summary: false)).to eq("au moins une nouveauté")
        end
      end
    end

    context "with a notification that is not a nouveauté" do
      it "only announces something in a summary" do
        expect(badge_notification_text_a11y(:attente_correction, summary: true)).to eq("dossiers")
        expect(badge_notification_text_a11y(:attente_correction, summary: false)).to be_nil
      end
    end
  end

  describe ".partage_badge" do
    subject { partage_badge }

    it { is_expected.to have_css(".fr-badge--blue-cumulus", text: "Partagé avec moi") }
  end

  describe ".new_message_badge" do
    subject { new_message_badge }

    it { is_expected.to have_css(".fr-badge--new", text: "MESSAGE") }
  end

  describe ".expiration_badge" do
    subject { expiration_badge(dossier) }

    context "when dossier is a brouillon close to expiration" do
      let(:dossier) { dossiers.brouillon }

      before { dossier.update_column(:expired_at, 5.days.from_now.change(hour: 23)) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire dans 5 j.") }
    end

    context "when dossier expires tomorrow" do
      let(:dossier) { dossiers.brouillon }

      before { dossier.update_column(:expired_at, 1.day.from_now.change(hour: 23)) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire demain") }
    end

    context "when dossier expires today" do
      let(:dossier) { dossiers.brouillon }

      before { dossier.update_column(:expired_at, Time.zone.now.end_of_day) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire aujourd’hui") }
    end

    context "when dossier is not close to expiration" do
      let(:dossier) { dossiers.brouillon }

      before { dossier.update_column(:expired_at, 1.year.from_now) }

      it { is_expected.to be_nil }
    end

    context "when dossier is en_construction (never expires)" do
      let(:dossier) { dossiers.en_construction }

      before { dossier.update_column(:expired_at, 5.days.from_now) }

      it { is_expected.to be_nil }
    end

    context "when dossier is termine" do
      let(:dossier) { dossiers.accepte }

      before { dossier.update_column(:expired_at, 5.days.from_now) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire dans 5 j.") }
    end
  end

  describe ".clean_string_for_pdf" do
    subject { clean_string_for_pdf(input) }

    context "when input contains multiple lines with various whitespace" do
      let(:input) { "un\tdeux\ntrois\rquatre\u00A0cinq&nbsp;six" }

      it "replaces all special whitespace with regular spaces" do
        expect(subject).to eq("un deux\ntrois\nquatre cinq six")
      end
    end
  end

  describe "#show_new_message_notification?" do
    let(:dossier) { create(:dossier, :en_construction) }

    subject { helper.show_new_message_notification?(dossier) }

    context "when an instructeur sent an unread message" do
      before { create(:commentaire, dossier:, instructeur: instructeurs.default, seen_by_recipient_at: nil) }

      it { is_expected.to be_truthy }
    end

    context "when an expert sent an unread message" do
      before { create(:commentaire, dossier:, expert: experts.default, seen_by_recipient_at: nil) }

      it { is_expected.to be_truthy }
    end

    context "when the dossier is en_instruction" do
      let(:dossier) { create(:dossier, :en_instruction) }

      before { create(:commentaire, dossier:, instructeur: instructeurs.default, seen_by_recipient_at: nil) }

      it { is_expected.to be_truthy }
    end

    context "when the agent message has been seen" do
      before { create(:commentaire, dossier:, instructeur: instructeurs.default, seen_by_recipient_at: 1.day.ago) }

      it { is_expected.to be_falsey }
    end

    context "when the agent message is discarded" do
      before { create(:commentaire, dossier:, instructeur: instructeurs.default, seen_by_recipient_at: nil, discarded_at: Time.current) }

      it { is_expected.to be_falsey }
    end

    context "when the message was sent by the usager" do
      before { create(:commentaire, dossier:, seen_by_recipient_at: nil) }

      it { is_expected.to be_falsey }
    end

    context "when the dossier has no message" do
      it { is_expected.to be_falsey }
    end

    context "when the dossier is pending_correction" do
      before do
        create(:commentaire, dossier:, instructeur: instructeurs.default, seen_by_recipient_at: nil)
        create(:dossier_correction, dossier:)
      end

      it { is_expected.to be_falsey }
    end

    context "when the dossier is pending_response" do
      before do
        create(:commentaire, dossier:, instructeur: instructeurs.default, seen_by_recipient_at: nil)
        create(:dossier_pending_response, dossier:)
      end

      it { is_expected.to be_falsey }
    end
  end
  describe ".pending_correction_badge" do
    it "words a complement request as such" do
      expect(pending_correction_badge(:for_user, reason: 'complement')).to have_text("à compléter", normalize_ws: true)
      expect(pending_correction_badge(:for_instructeur, reason: 'complement')).to have_text("en attente de complément", normalize_ws: true)
    end

    it "falls back on the correction wording for a reason without its own" do
      expect(pending_correction_badge(:for_user, reason: 'incorrect')).to have_text("à corriger", normalize_ws: true)
      expect(pending_correction_badge(:for_instructeur, reason: 'incomplete')).to have_text("en attente de correction", normalize_ws: true)
    end
  end

  describe ".correction_resolved_badge" do
    it "words a cancelled complement request as such" do
      expect(correction_resolved_badge(:discarded, reason: 'complement')).to have_text("Demande de complément annulée", normalize_ws: true)
    end

    it "keeps the neutral wording shared by every reason" do
      expect(correction_resolved_badge(:modified, reason: 'complement')).to have_text("Dossier modifié", normalize_ws: true)
    end
  end
end
