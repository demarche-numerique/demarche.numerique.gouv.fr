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
      let(:dossier) { create(:dossier, state: Dossier.states.fetch(:brouillon)) }
      it { is_expected.to eq "/dossiers/#{dossier.id}/brouillon" }
    end

    context "when the dossier is any other state" do
      let(:dossier) { create(:dossier, state: Dossier.states.fetch(:en_construction)) }
      it { is_expected.to eq "/dossiers/#{dossier.id}" }
    end
  end

  describe ".demandeur_dossier" do
    subject { demandeur_dossier(dossier) }

    let(:individual) { build(:individual, dossier: nil) }
    let(:etablissement) { build(:etablissement) }
    let(:dossier) { create(:dossier, procedure: procedure, individual: individual, etablissement: etablissement) }

    context "when the dossier is for an individual" do
      let(:procedure) { create(:simple_procedure, :for_individual) }

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
    let(:dossier) { create(:dossier, state: state) }
    let(:state) { Dossier.states.fetch(:brouillon) }

    subject { dossier_submission_is_closed?(dossier) }

    context "when dossier state is brouillon" do
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
      let(:state) { Dossier.states.fetch(:en_construction) }

      it_behaves_like "returns false"
    end

    context "when dossier state is en_construction" do
      let(:state) { Dossier.states.fetch(:en_instruction) }

      it_behaves_like "returns false"
    end

    context "when dossier state is en_construction" do
      let(:state) { Dossier.states.fetch(:accepte) }

      it_behaves_like "returns false"
    end

    context "when dossier state is en_construction" do
      let(:state) { Dossier.states.fetch(:refuse) }

      it_behaves_like "returns false"
    end

    context "when dossier state is en_construction" do
      let(:state) { Dossier.states.fetch(:sans_suite) }

      it_behaves_like "returns false"
    end
  end

  describe '.dossier_display_state' do
    let(:dossier) { create(:dossier) }

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
      let(:dossier) { create(:dossier) }

      it { is_expected.to eq('brouillon') }
    end

    context 'when the dossier is en instruction' do
      let(:dossier) { create(:dossier, :en_instruction) }

      it { is_expected.to eq('received') }
    end

    context 'when the dossier is accepte' do
      let(:dossier) { create(:dossier, state: Dossier.states.fetch(:accepte)) }

      it { is_expected.to eq('closed') }
    end

    context 'when the dossier is refuse' do
      let(:dossier) { create(:dossier, state: Dossier.states.fetch(:refuse)) }

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
      let(:instructeur) { create(:instructeur) }
      let(:dossier) { create(:dossier, depose_at: 10.days.ago) }
      let!(:notification) { create(:dossier_notification, instructeur:, dossier:, notification_type: :dossier_depose, display_at: (dossier.depose_at + DossierNotification::DELAY_DOSSIER_DEPOSE)) }

      it {
        expect(subject).to have_text("Déposé depuis 10 J.")
      }
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
      let(:dossier) { create(:dossier) }

      before { dossier.update_column(:expired_at, 5.days.from_now.change(hour: 23)) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire dans 5 j.") }
    end

    context "when dossier expires tomorrow" do
      let(:dossier) { create(:dossier) }

      before { dossier.update_column(:expired_at, 1.day.from_now.change(hour: 23)) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire demain") }
    end

    context "when dossier expires today" do
      let(:dossier) { create(:dossier) }

      before { dossier.update_column(:expired_at, Time.zone.now.end_of_day) }

      it { is_expected.to have_css(".fr-badge--warning", text: "Expire aujourd’hui") }
    end

    context "when dossier is not close to expiration" do
      let(:dossier) { create(:dossier) }

      before { dossier.update_column(:expired_at, 1.year.from_now) }

      it { is_expected.to be_nil }
    end

    context "when dossier is en_construction (never expires)" do
      let(:dossier) { create(:dossier, :en_construction) }

      before { dossier.update_column(:expired_at, 5.days.from_now) }

      it { is_expected.to be_nil }
    end

    context "when dossier is termine" do
      let(:procedure) { create(:procedure, :published) }
      let(:dossier) { create(:dossier, :accepte, procedure:) }

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
end
