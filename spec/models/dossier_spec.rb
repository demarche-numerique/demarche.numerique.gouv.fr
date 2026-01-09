# frozen_string_literal: true

describe Dossier, type: :model do
  include ActionView::Helpers::SanitizeHelper

  let(:user) { create(:user) }

  describe 'has_many preloaded_commentaires' do
    let(:dossier) { create(:dossier) }
    let!(:commentaire) { create :commentaire, created_at: '2016-03-14', dossier: }
    let!(:commentaire_2) { create :commentaire, created_at: '2016-03-15', dossier: }
    let!(:commentaire_3) { create :commentaire, created_at: '2016-03-16', dossier: }

    it 'returns commentaires in desc order' do
      expect(dossier.preloaded_commentaires).to eq([commentaire_3, commentaire_2, commentaire])
    end
  end

  describe 'scopes' do
    describe '.default_scope' do
      let!(:dossier) { create(:dossier) }

      subject { Dossier.all }

      it { is_expected.to match_array([dossier]) }
    end

    describe '.without_followers' do
      let!(:dossier_with_follower) { create(:dossier, :followed, :with_entreprise, user: user) }
      let!(:dossier_without_follower) { create(:dossier, :with_entreprise, user: user) }

      it { expect(Dossier.without_followers.to_a).to eq([dossier_without_follower]) }
    end

    describe 'brouillons_recently_updated' do
      let!(:dossier_en_brouillon) { create(:dossier) }
      let!(:dossier_en_brouillon_2) { create(:dossier) }

      it { expect(Dossier.brouillons_recently_updated).to eq([dossier_en_brouillon_2, dossier_en_brouillon]) }
    end

    describe 'by_statut' do
      let(:procedure) { create(:procedure) }
      let(:dossier_en_construction) { create(:dossier, :en_construction, procedure:) }
      let(:dossier_en_instruction) { create(:dossier, :en_instruction, procedure:) }
      let(:dossier_accepte) { create(:dossier, :accepte, procedure:) }
      let(:dossier_refuse) { create(:dossier, :refuse, procedure:) }
      let(:dossier_accepte_archive) { create(:dossier, :accepte, :archived, procedure:) }
      let(:dossier_accepte_deleted) { create(:dossier, :accepte, :hidden_by_administration, procedure:) }
      let(:dossier_accepte_archive_deleted) { create(:dossier, :accepte, :archived, :hidden_by_administration, procedure:) }

      let!(:dossiers) { [dossier_en_construction, dossier_en_instruction, dossier_accepte, dossier_refuse] }

      context 'tous' do
        it do
          expect(procedure.dossiers.by_statut('tous')).to match_array(dossiers - [dossier_accepte_archive, dossier_accepte_archive_deleted])
        end
      end

      context 'a-suivre' do
        it do
          expect(procedure.dossiers.by_statut('a-suivre')).to match_array([dossier_en_construction, dossier_en_instruction])
        end
      end

      context 'supprimes' do
        it do
          expect(procedure.dossiers.by_statut('supprimes')).to match_array([dossier_accepte_deleted, dossier_accepte_archive_deleted])
        end
      end

      context 'archives' do
        it do
          expect(procedure.dossiers.by_statut('archives')).to match_array([dossier_accepte_archive])
        end
      end
    end

    describe '.brouillon_expired' do
      let(:interval_between_first_and_second_expiration) { Dossier::MONTHS_AFTER_EXPIRATION.months + Dossier::DAYS_AFTER_EXPIRATION.days }

      let!(:dossier_brouillon_expired_and_noticed_long_time_ago) do
        travel_to(5.months.ago) do
          create(:dossier,
            state: :brouillon,
            brouillon_close_to_expiration_notice_sent_at: 1.day.ago)
        end
      end

      let!(:dossier_brouillon_not_expired) do
        travel_to(1.month.ago) do
          create(:dossier,
            state: :brouillon)
        end
      end

      let!(:dossier_brouillon_expired_but_noticed_recently) do
        travel_to(5.months.ago) do
          create(:dossier,
            state: :brouillon,
            brouillon_close_to_expiration_notice_sent_at: (4.months + 20.days).from_now)
        end
      end

      let!(:dossier_brouillon_expired_but_not_noticed_yet) do
        travel_to(5.months.ago) do
          create(:dossier,
            state: :brouillon)
        end
      end

      let!(:dossier_instruction_expired) do
        travel_to(5.months.ago) do
          create(:dossier,
            state: :en_instruction,
            brouillon_close_to_expiration_notice_sent_at: 1.day.ago)
        end
      end

      let!(:dossier_hidden) do
        travel_to(5.months.ago) do
          create(:dossier,
            state: :brouillon,
            brouillon_close_to_expiration_notice_sent_at: 1.day.ago,
            hidden_by_user_at: Time.zone.now)
        end
      end

      it 'returns only visible brouillon dossiers whose expiration notice period has passed' do
        expect(Dossier.brouillon_expired).to contain_exactly(dossier_brouillon_expired_and_noticed_long_time_ago)
      end
    end
  end

  describe 'validations' do
    let(:procedure) { create(:procedure, :for_individual) }
    subject(:dossier) { create(:dossier, procedure: procedure) }

    it 'validates presence of required attributes' do
      is_expected.to validate_presence_of(:individual)
      is_expected.to validate_presence_of(:user)
    end

    context 'when dossier has deleted_user_email_never_send' do
      subject(:dossier) { create(:dossier, procedure: procedure, deleted_user_email_never_send: "seb@totoro.org") }

      it { is_expected.not_to validate_presence_of(:user) }
    end

    context 'when dossier is prefilled' do
      subject(:dossier) { create(:dossier, procedure: procedure, prefilled: true) }

      it { is_expected.not_to validate_presence_of(:user) }
    end
  end

  describe 'brouillon_close_to_expiration' do
    let(:procedure) { create(:procedure, :published, duree_conservation_dossiers_dans_ds: 6) }
    let!(:young_dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:expiring_dossier) { create(:dossier, updated_at: 85.days.ago, procedure: procedure) }
    let!(:expiring_dossier_with_notification) { create(:dossier, updated_at: 85.days.ago, brouillon_close_to_expiration_notice_sent_at: Time.zone.now, procedure: procedure) }
    let!(:just_expired_dossier) { create(:dossier, updated_at: (6.months + 1.hour + 10.seconds).ago, procedure: procedure) }
    let!(:long_expired_dossier) { create(:dossier, updated_at: 1.year.ago, procedure: procedure) }

    subject { Dossier.brouillon_close_to_expiration }

    it do
      is_expected.not_to include(young_dossier)
      is_expected.to include(expiring_dossier)
      is_expected.to include(just_expired_dossier)
      is_expected.to include(long_expired_dossier)

      expect(expiring_dossier.close_to_expiration?).to be_truthy
      expect(expiring_dossier_with_notification.close_to_expiration?).to be_truthy
    end

    context 'does not include an expiring dossier that has been postponed' do
      before do
        expiring_dossier.extend_conservation(1.month)
        expiring_dossier_with_notification.extend_conservation(1.month)
        expiring_dossier.reload
        expiring_dossier_with_notification.reload
      end

      it do
        is_expected.not_to include(expiring_dossier)

        expect(expiring_dossier.close_to_expiration?).to be_falsey
        expect(expiring_dossier_with_notification.close_to_expiration?).to be_falsey

        expect(expiring_dossier.expiration_date).to eq(expiring_dossier.expiration_date_with_extension)
        expect(expiring_dossier_with_notification.expiration_date).to eq(expiring_dossier_with_notification.expiration_date_with_extension)
      end
    end

    context 'when .close_to_expiration' do
      subject { Dossier.close_to_expiration }
      it do
        is_expected.not_to include(young_dossier)
        is_expected.to include(expiring_dossier)
        is_expected.to include(just_expired_dossier)
        is_expected.to include(long_expired_dossier)
      end
    end
  end

  describe 'en_construction_close_to_expiration' do
    let(:procedure) { create(:procedure, :published, duree_conservation_dossiers_dans_ds: 6) }
    let!(:young_dossier) { create(:dossier, procedure: procedure) }
    let!(:expiring_dossier) { create(:dossier, :en_construction, en_construction_at: 175.days.ago, procedure: procedure) }
    let!(:expiring_dossier_with_notification) { create(:dossier, :en_construction, en_construction_at: 175.days.ago, en_construction_close_to_expiration_notice_sent_at: Time.zone.now, procedure: procedure) }
    let!(:just_expired_dossier) { create(:dossier, :en_construction, en_construction_at: (6.months + 1.hour + 10.seconds).ago, procedure: procedure) }
    let!(:long_expired_dossier) { create(:dossier, :en_construction, en_construction_at: 1.year.ago, procedure: procedure) }

    subject { Dossier.en_construction_close_to_expiration }

    before { procedure.dossiers.each(&:update_expired_at) }

    it do
      is_expected.not_to include(young_dossier)
      is_expected.to include(expiring_dossier)
      is_expected.to include(just_expired_dossier)
      is_expected.to include(long_expired_dossier)
      expect(expiring_dossier.reload.close_to_expiration?).to be_truthy
      expect(expiring_dossier_with_notification.reload.close_to_expiration?).to be_truthy
    end

    context 'does not include an expiring dossier that has been postponed' do
      before do
        expiring_dossier.extend_conservation(1.month)
        expiring_dossier_with_notification.extend_conservation(1.month)
        expiring_dossier.reload
        expiring_dossier_with_notification.reload
      end

      it do
        is_expected.not_to include(expiring_dossier)

        expect(expiring_dossier.close_to_expiration?).to be_falsey
        expect(expiring_dossier_with_notification.close_to_expiration?).to be_falsey

        expect(expiring_dossier.expiration_date).to eq(expiring_dossier.expiration_date_with_extension)
        expect(expiring_dossier_with_notification.expiration_date).to eq(expiring_dossier_with_notification.expiration_date_with_extension)
      end
    end

    context 'when .close_to_expiration' do
      subject { Dossier.close_to_expiration }
      it do
        is_expected.not_to include(young_dossier)
        is_expected.to include(expiring_dossier)
        is_expected.to include(just_expired_dossier)
        is_expected.to include(long_expired_dossier)
      end
    end

    context 'when .termine_or_en_construction_close_to_expiration' do
      subject { Dossier.termine_or_en_construction_close_to_expiration }
      it do
        is_expected.not_to include(young_dossier)
        is_expected.to include(expiring_dossier)
        is_expected.to include(just_expired_dossier)
        is_expected.to include(long_expired_dossier)
      end
    end
  end

  describe 'termine_close_to_expiration' do
    let(:procedure) { create(:procedure, :published, duree_conservation_dossiers_dans_ds: 6, procedure_expires_when_termine_enabled: true) }
    let!(:young_dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: 2.days.ago) }
    let!(:expiring_dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: 175.days.ago) }
    let!(:expiring_dossier_with_notification) { create(:dossier, state: :accepte, procedure: procedure, processed_at: 175.days.ago, termine_close_to_expiration_notice_sent_at: Time.zone.now) }
    let!(:just_expired_dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: (6.months + 1.hour + 10.seconds).ago) }
    let!(:long_expired_dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: 1.year.ago) }

    subject { Dossier.termine_close_to_expiration }

    before { procedure.dossiers.each(&:update_expired_at) }

    it do
      is_expected.not_to include(young_dossier)
      is_expected.to include(expiring_dossier)
      is_expected.to include(just_expired_dossier)
      is_expected.to include(long_expired_dossier)

      expect(expiring_dossier.reload.close_to_expiration?).to be_truthy
      expect(expiring_dossier_with_notification.reload.close_to_expiration?).to be_truthy
    end

    context 'does not include an expiring dossier that has been postponed' do
      before do
        expiring_dossier.extend_conservation(1.month)
        expiring_dossier_with_notification.extend_conservation(1.month)
        expiring_dossier.reload
        expiring_dossier_with_notification.reload
      end

      it do
        is_expected.not_to include(expiring_dossier)

        expect(expiring_dossier.close_to_expiration?).to be_falsey
        expect(expiring_dossier_with_notification.close_to_expiration?).to be_falsey

        expect(expiring_dossier.expiration_date).to eq(expiring_dossier.expiration_date_with_extension)
        expect(expiring_dossier_with_notification.expiration_date).to eq(expiring_dossier_with_notification.expiration_date_with_extension)
      end
    end

    context 'when .close_to_expiration' do
      subject { Dossier.close_to_expiration }
      it do
        is_expected.not_to include(young_dossier)
        is_expected.to include(expiring_dossier)
        is_expected.to include(just_expired_dossier)
        is_expected.to include(long_expired_dossier)
      end
    end

    context 'when .close_to_expiration' do
      subject { Dossier.termine_or_en_construction_close_to_expiration }
      it do
        is_expected.not_to include(young_dossier)
        is_expected.to include(expiring_dossier)
        is_expected.to include(just_expired_dossier)
        is_expected.to include(long_expired_dossier)
      end
    end
  end

  describe "#extend_conservation" do
    subject { dossier.extend_conservation(1.month) }

    let(:dossier) { create(:dossier, :en_construction) }

    context "when the dossier has a dossier_expirant notification" do
      let!(:notification_expirant) { create(:dossier_notification, dossier:, notification_type: :dossier_expirant) }

      it "destroys dossier_expirant notification" do
        subject
        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe "#restore" do
    subject { dossier.restore(author) }

    let(:dossier) { create(:dossier, :en_construction, :with_individual, hidden_by_administration_at: 1.hour.ago) }

    context "when an instructeur restore the dossier" do
      let(:author) { create(:instructeur) }

      context "when there is a dossier_suppression notification" do
        let!(:notification_suppression) { create(:dossier_notification, dossier:, notification_type: :dossier_suppression) }

        it "destroys the notification" do
          subject
          expect(DossierNotification.count).to eq(0)
        end
      end
    end
  end

  describe 'methods' do
    let(:dossier) { create(:dossier, :with_entreprise, user: user) }
    let(:etablissement) { dossier.etablissement }

    subject { dossier }

    describe '#build_default_values' do
      let(:dossier) { build(:dossier, procedure: procedure, user: user) }

      subject do
        dossier.individual = nil
        dossier.build_default_values
      end

      context 'when the dossier belongs to a procedure for individuals' do
        let(:procedure) { create(:procedure, for_individual: true) }

        it 'creates a default individual' do
          subject
          expect(dossier.individual).to be_present
          expect(dossier.individual.nom).to be_nil
          expect(dossier.individual.prenom).to be_nil
          expect(dossier.individual.gender).to be_nil
        end

        context 'and the user signs-in using France Connect' do
          let(:user) { create(:user, france_connect_informations: [build(:france_connect_information)]) }

          it 'fills the individual with the informations from France Connect' do
            subject
            expect(dossier.individual.nom).to eq('DUBOIS')
            expect(dossier.individual.prenom).to eq('Angela Claire Louise')
            expect(dossier.individual.gender).to eq(Individual::GENDER_FEMALE)
          end
        end
        context 'and the user signs-in using France Connect many times' do
          let(:user) { create(:user, france_connect_informations: [build(:france_connect_information), build(:france_connect_information)]) }

          it 'fills the individual with the informations from France Connect' do
            subject
            expect(dossier.individual.nom).to eq(nil)
            expect(dossier.individual.prenom).to eq(nil)
            expect(dossier.individual.gender).to eq(nil)
          end
        end
      end

      context 'when the dossier belongs to a procedure for moral personas' do
        let(:procedure) { create(:procedure, for_individual: false) }

        it 'doesn’t create a individual' do
          subject
          expect(dossier.individual).to be_nil
        end
      end
    end

    describe '#last_booked_rdv' do
      let(:dossier) { create(:dossier) }
      let(:instructeur) { create(:instructeur) }

      context 'when there are no booked RDVs' do
        it 'returns nil' do
          expect(dossier.last_booked_rdv).to be_nil
        end
      end

      context 'when there are RDVs' do
        let!(:booked1) { create(:rdv, :booked, dossier: dossier, instructeur: instructeur, starts_at: 1.day.from_now) }
        let!(:booked2) { create(:rdv, :booked, dossier: dossier, instructeur: instructeur, starts_at: 2.days.from_now) }
        let!(:not_booked) { create(:rdv, dossier: dossier, instructeur: instructeur, starts_at: 3.days.from_now) }

        it 'returns the RDV with the latest starts_at' do
          expect(dossier.last_booked_rdv).to eq(booked2)
        end
      end
    end
  end

  context 'when dossier is followed' do
    let(:procedure) { create(:procedure, :with_type_de_champ, :with_type_de_champ_private) }
    let(:instructeur) { create(:instructeur) }
    let(:date1) { 1.day.ago }
    let(:date2) { 1.hour.ago }
    let(:date3) { 1.minute.ago }
    let(:dossier) do
      d = create(:dossier, :with_entreprise, user: user, procedure: procedure)
      travel_to(date1)
      d.passer_en_construction!
      travel_to(date2)
      d.passer_en_instruction!(instructeur: instructeur)
      travel_to(date3)
      d.accepter!(instructeur: instructeur, motivation: "Motivation")
      travel_back
      d.reload
    end

    describe "followers_instructeurs" do
      let(:non_following_instructeur) { create(:instructeur) }
      subject { dossier.followers_instructeurs }

      it do
        expect(subject).to eq [instructeur]
        expect(subject).not_to include(non_following_instructeur)
      end
    end
  end

  describe "#text_summary" do
    let(:service) { create(:service, nom: 'nom du service') }
    let(:procedure) { create(:procedure, libelle: "Démarche", organisation: "Organisme", service: service) }

    context 'when the dossier has been submitted' do
      let(:dossier) { create :dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction), depose_at: "31/12/2010".to_date }

      subject { dossier.text_summary }

      it { is_expected.to eq("Dossier déposé le 31/12/2010 sur la démarche Démarche gérée par l’organisme nom du service") }
    end

    context 'when the dossier has not been submitted' do
      let(:dossier) { create :dossier, procedure: procedure, state: Dossier.states.fetch(:brouillon) }

      subject { dossier.text_summary }

      it { is_expected.to eq("Dossier en brouillon répondant à la démarche Démarche gérée par l’organisme nom du service") }
    end
  end

  describe '#avis_for' do
    let!(:instructeur) { create(:instructeur) }
    let!(:procedure) { create(:procedure, :published, instructeurs: [instructeur]) }
    let!(:dossier) { create(:dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction)) }
    let!(:experts_procedure) { create(:experts_procedure, expert: expert_1, procedure: procedure) }
    let!(:experts_procedure_2) { create(:experts_procedure, expert: expert_2, procedure: procedure) }
    let!(:expert_1) { create(:expert) }
    let!(:expert_2) { create(:expert) }

    context 'when there is a public advice asked from the dossiers instructeur' do
      let!(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: false) }

      it do
        expect(dossier.avis_for_expert(expert_1)).to match([avis])
        expect(dossier.avis_for_expert(expert_2)).to match([avis])
      end
    end

    context 'when there is a private advice asked from the dossiers instructeur' do
      let!(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: true) }

      it do
        expect(dossier.avis_for_expert(expert_1)).to match([avis])
        expect(dossier.avis_for_expert(expert_2)).not_to match([avis])
      end
    end

    context 'when there is a public advice asked from one instructeur to an expert' do
      let!(:avis_1) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: false) }
      let!(:avis_2) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure_2, confidentiel: false) }

      it do
        expect(dossier.avis_for_expert(expert_1)).to match([avis_1, avis_2])
        expect(dossier.avis_for_expert(expert_2)).to match([avis_1, avis_2])
      end
    end

    context 'when there is a private advice asked from one instructeur to an expert' do
      let!(:avis_1) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: true) }
      let!(:avis_2) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure_2, confidentiel: true) }

      it do
        expect(dossier.avis_for_expert(expert_1)).to match([avis_1])
        expect(dossier.avis_for_expert(expert_2)).to match([avis_2])
      end
    end

    context 'when there are private avis asked from one expert to another expert' do
      let!(:avis_1) { create(:avis, dossier: dossier, claimant: expert_1, experts_procedure: experts_procedure_2, confidentiel: true) }
      let!(:avis_2) { create(:avis, dossier: dossier, claimant: expert_2, experts_procedure: experts_procedure, confidentiel: true) }

      it 'experts can see both asked and received avis' do
        expect(dossier.avis_for_expert(expert_1)).to match([avis_1, avis_2])
        expect(dossier.avis_for_expert(expert_2)).to match([avis_1, avis_2])
      end
    end

    context 'when there are public avis asked from one expert to another expert' do
      let!(:avis_1) { create(:avis, dossier: dossier, claimant: expert_1, experts_procedure: experts_procedure_2, confidentiel: false) }
      let!(:avis_2) { create(:avis, dossier: dossier, claimant: expert_2, experts_procedure: experts_procedure, confidentiel: false) }

      it 'experts can see both asked and received avis' do
        expect(dossier.avis_for_expert(expert_1)).to match([avis_1, avis_2])
        expect(dossier.avis_for_expert(expert_2)).to match([avis_1, avis_2])
      end
    end

    context 'when they are a lot of advice' do
      let!(:avis_1) { create(:avis, dossier: dossier, claimant: expert_1, experts_procedure: experts_procedure_2, confidentiel: false, created_at: Time.zone.parse('10/01/2010')) }
      let!(:avis_2) { create(:avis, dossier: dossier, claimant: expert_1, experts_procedure: experts_procedure_2, confidentiel: false, created_at: Time.zone.parse('9/01/2010')) }
      let!(:avis_3) { create(:avis, dossier: dossier, claimant: expert_1, experts_procedure: experts_procedure_2, confidentiel: false, created_at: Time.zone.parse('11/01/2010')) }

      it { expect(dossier.avis_for_expert(expert_1)).to match([avis_2, avis_1, avis_3]) }
    end

    context 'when they are a advice published on another dossier' do
      let!(:avis) { create(:avis, dossier: create(:dossier, procedure: procedure), claimant: instructeur, experts_procedure: experts_procedure, confidentiel: false, created_at: Time.zone.parse('9/01/2010')) }

      it { expect(dossier.avis_for_expert(expert_1)).to match([]) }
    end
  end

  describe '#update_state_dates' do
    let(:dossier) { create(:dossier, :brouillon, :with_individual) }
    let(:beginning_of_day) { Time.zone.now.beginning_of_day }
    let(:instructeur) { create(:instructeur) }

    before { travel_to(beginning_of_day) }

    context 'when dossier is en_construction' do
      context 'when the procedure.routing_enabled? is false' do
        subject do
          dossier.passer_en_construction!
          dossier.reload
        end

        it do
          subject
          expect(dossier.state).to eq(Dossier.states.fetch(:en_construction))
          expect(dossier.en_construction_at).to eq(beginning_of_day)
          expect(dossier.depose_at).to eq(beginning_of_day)
          expect(dossier.traitement.state).to eq(Dossier.states.fetch(:en_construction))
          expect(dossier.traitement.processed_at).to eq(beginning_of_day)
          expect(dossier.expired_at).to eq(dossier.expiration_date)
        end

        it 'should keep first en_construction_at date' do
          subject
          travel_back
          dossier.passer_en_instruction!(instructeur: instructeur)
          dossier.repasser_en_construction!(instructeur: instructeur)

          expect(dossier.traitements.size).to eq(3)
          expect(dossier.traitements.first.processed_at).to eq(beginning_of_day)
          expect(dossier.traitement.processed_at.round).to eq(dossier.en_construction_at.round)
          expect(dossier.depose_at).to eq(beginning_of_day)
          expect(dossier.en_construction_at).to be > beginning_of_day
        end
      end

      context 'when the procedure.routing_enabled? is true' do
        include Logic
        let(:gi_libelle) { 'Paris' }
        let!(:procedure) do
          create(:procedure,
                 types_de_champ_public: [
                   { type: :drop_down_list, libelle: 'Votre ville', options: [gi_libelle, 'Lyon', 'Marseille'] },
                   { type: :text, libelle: 'Un champ texte' },
                 ])
        end
        let!(:drop_down_tdc) { procedure.draft_revision.types_de_champ.first }
        let(:dossier) { create(:dossier, :brouillon, user:, procedure:, groupe_instructeur: nil) }
        let(:gi) do
          create(:groupe_instructeur,
                   routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id),
                                       constant(gi_libelle)))
        end

        before do
          procedure.groupe_instructeurs = [gi]
          procedure.defaut_groupe_instructeur = gi
          procedure.save!
          procedure.toggle_routing
          dossier.champs.first.value = gi_libelle
          dossier.save!
          dossier.passer_en_construction!
          dossier.reload
        end

        it 'RoutingEngine.compute' do
          expect(dossier.groupe_instructeur).not_to be_nil
        end
      end
    end

    context 'when dossier is en_instruction' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual) }
      let(:instructeur) { create(:instructeur) }

      before do
        dossier.passer_en_instruction!(instructeur: instructeur)
        dossier.reload
      end

      it do
        expect(dossier.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(dossier.en_instruction_at).to eq(beginning_of_day)
        expect(dossier.traitement.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(dossier.traitement.processed_at).to eq(beginning_of_day)
        expect(dossier.expired_at).to be_nil
      end

      it 'should keep first en_instruction_at date if dossier is set to en_construction again' do
        travel_back
        dossier.repasser_en_construction!(instructeur: instructeur)
        dossier.passer_en_instruction!(instructeur: instructeur)

        expect(dossier.traitements.size).to eq(4)
        expect(dossier.traitements.en_construction.first.processed_at).to eq(dossier.depose_at)
        expect(dossier.traitements.en_instruction.first.processed_at).to eq(beginning_of_day)
        expect(dossier.traitement.processed_at.round).to eq(dossier.en_instruction_at.round)
        expect(dossier.en_instruction_at).to be > beginning_of_day
      end
    end

    context 'when dossier is accepte' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual) }

      before do
        dossier.accepter!(instructeur: instructeur)
        dossier.reload
      end

      it do
        expect(dossier.state).to eq(Dossier.states.fetch(:accepte))
        expect(dossier.processed_at).to eq(beginning_of_day)
        expect(dossier.traitement.state).to eq(Dossier.states.fetch(:accepte))
        expect(dossier.traitement.processed_at).to eq(beginning_of_day)
        expect(dossier.expired_at).to eq(dossier.expiration_date)
      end
    end

    context 'when dossier is refuse' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual) }

      before do
        dossier.refuser!(instructeur: instructeur)
        dossier.reload
      end

      it do
        expect(dossier.state).to eq(Dossier.states.fetch(:refuse))
        expect(dossier.processed_at).to eq(beginning_of_day)
        expect(dossier.traitement.state).to eq(Dossier.states.fetch(:refuse))
        expect(dossier.traitement.processed_at).to eq(beginning_of_day)
        expect(dossier.expired_at).to eq(dossier.expiration_date)
      end
    end

    context 'when dossier is sans_suite' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual) }

      before do
        dossier.classer_sans_suite!(instructeur: instructeur)
        dossier.reload
      end

      it do
        expect(dossier.state).to eq(Dossier.states.fetch(:sans_suite))
        expect(dossier.processed_at).to eq(beginning_of_day)
        expect(dossier.traitement.state).to eq(Dossier.states.fetch(:sans_suite))
        expect(dossier.traitement.processed_at).to eq(beginning_of_day)
        expect(dossier.expired_at).to eq(dossier.expiration_date)
      end
    end
  end

  describe '.ordered_for_export' do
    let(:procedure) { create(:procedure) }
    let!(:dossier2) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_construction), depose_at: Time.zone.parse('03/01/2010')) }
    let!(:dossier3) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_instruction), depose_at: Time.zone.parse('01/01/2010')) }
    let!(:dossier4) { create(:dossier, :with_entreprise, procedure: procedure, state: Dossier.states.fetch(:en_instruction), archived: true, depose_at: Time.zone.parse('02/01/2010')) }

    subject { procedure.dossiers.ordered_for_export }

    it { is_expected.to match([dossier3, dossier4, dossier2]) }
  end

  describe "#assign_to_groupe_instructeur" do
    let(:procedure) { create(:procedure) }
    let(:new_groupe_instructeur_new_procedure) { create(:groupe_instructeur) }
    let(:new_instructeur) { create(:instructeur) }
    let(:new_groupe_instructeur) { create(:groupe_instructeur, procedure: procedure, instructeurs: [new_instructeur]) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it "can change groupe instructeur" do
      dossier.assign_to_groupe_instructeur(new_groupe_instructeur_new_procedure, DossierAssignment.modes.fetch(:auto))
      expect(dossier.groupe_instructeur).not_to eq(new_groupe_instructeur_new_procedure)
    end

    it "can not change groupe instructeur if new groupe is from another procedure" do
      dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))
      expect(dossier.groupe_instructeur).to eq(new_groupe_instructeur)
    end

    context "when the groupe instructeur change" do
      let(:procedure) { create(:procedure) }
      let(:instructeur) { create(:instructeur) }
      let(:new_instructeur) { create(:instructeur) }
      let(:previous_groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }
      let(:dossier) { create(:dossier, :en_construction, groupe_instructeur: previous_groupe_instructeur, procedure:) }

      context "when an instructeur of the previous groupe is not is the new groupe" do
        let(:new_groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [new_instructeur]) }

        context "when this instructeur has notifications on the dossier" do
          let!(:notification) { create(:dossier_notification, dossier:, instructeur:) }

          it "destroys all of its notifications" do
            dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))
            expect(DossierNotification.all).not_to include(notification)
          end
        end
      end

      context "when an instructeur is in both the previous groupe and the new groupe" do
        let(:new_groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur, new_instructeur]) }

        context "when this instructeur has notifications on the dossier" do
          let!(:notification) { create(:dossier_notification, dossier:, instructeur:) }

          it "does not destroy its notifications" do
            dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))
            expect(DossierNotification.all).to include(notification)
          end
        end

        context "when this instructeur has already had a previous notification" do
          let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, display_dossier_modifie_notifications: 'all') }

          before { dossier.update!(last_champ_updated_at: Time.zone.now, depose_at: Time.zone.yesterday) }

          it "does not refresh a previous notification" do
            dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))
            expect(DossierNotification.where(instructeur:, dossier:, notification_type: :dossier_modifie)).to be_empty
          end
        end
      end

      context "when an instructeur of the new groupe is not is the previous groupe" do
        let(:new_groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [new_instructeur]) }
        let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur: new_instructeur, procedure:, display_dossier_modifie_notifications: 'followed') }

        before { dossier.update!(last_champ_updated_at: Time.zone.now, depose_at: Time.zone.yesterday) }

        it "refreshes notifications for which the new instructeur has an 'all' preference" do
          dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))
          expect(DossierNotification.where(instructeur: new_instructeur, dossier:, notification_type: :dossier_modifie)).to be_empty
          expect(DossierNotification.where(instructeur: new_instructeur, dossier:, notification_type: :dossier_depose)).to be_present
        end
      end

      context "when dossier must have a non customisable notification" do
        let(:new_groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [new_instructeur]) }

        context "when notification is dossier_expirant" do
          before { dossier.update(expired_at: 1.week.from_now) }

          it "refreshes notifications for new instructeur" do
            dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))

            notification = DossierNotification.find_by!(instructeur: new_instructeur, dossier:, notification_type: :dossier_expirant)
            expect(notification.display_at.to_date).to eq(1.week.ago.to_date)
          end
        end

        context "when notification is dossier_suppression" do
          context "when dossier is expired" do
            before { dossier.update(hidden_by_expired_at: Time.zone.yesterday) }

            it "refreshes notifications for new instructeur" do
              dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))

              notification = DossierNotification.find_by!(instructeur: new_instructeur, dossier:, notification_type: :dossier_suppression)
              expect(notification.display_at.to_date).to eq(Time.zone.yesterday.to_date)
            end
          end

          context "when dossier is hidden by administration and by user" do
            before { dossier.update(hidden_by_administration_at: Time.zone.yesterday, hidden_by_user_at: 1.week.ago) }

            it "refreshes notifications for new instructeur" do
              dossier.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto))

              notification = DossierNotification.find_by!(instructeur: new_instructeur, dossier:, notification_type: :dossier_suppression)
              expect(notification.display_at.to_date).to eq(Time.zone.yesterday.to_date)
            end
          end
        end
      end
    end
  end

  describe "#unfollow_stale_instructeurs" do
    let(:procedure) { create(:procedure, :published, :for_individual) }
    let(:instructeur) { create(:instructeur) }
    let(:new_groupe_instructeur) { create(:groupe_instructeur, procedure: procedure) }
    let(:instructeur2) { create(:instructeur, groupe_instructeurs: [procedure.defaut_groupe_instructeur, new_groupe_instructeur]) }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }
    let(:last_operation) { DossierOperationLog.last }

    before do
      allow(DossierMailer).to receive(:notify_groupe_instructeur_changed).and_return(double(deliver_later: nil))
    end

    it "unfollows stale instructeurs when groupe instructeur change" do
      instructeur.follow(dossier)
      instructeur2.follow(dossier)
      dossier.reload.assign_to_groupe_instructeur(new_groupe_instructeur, DossierAssignment.modes.fetch(:auto), procedure.administrateurs.first)

      expect(dossier.followers_instructeurs).not_to include(instructeur)
      expect(dossier.followers_instructeurs).to include(instructeur2)

      expect(DossierMailer).to have_received(:notify_groupe_instructeur_changed).with(instructeur, dossier)
      expect(DossierMailer).not_to have_received(:notify_groupe_instructeur_changed).with(instructeur2, dossier)

      expect(last_operation.operation).to eq("changer_groupe_instructeur")
      expect(last_operation.dossier).to eq(dossier)
      expect(last_operation.automatic_operation?).to be_falsey
    end

    it "resets the followers_instructeurs association cache" do
      instructeur.follow(dossier)
      instructeur2.follow(dossier)

      dossier.send(:unfollow_stale_instructeurs)

      expect(dossier.followers_instructeurs).not_to include(instructeur)
      expect(dossier.followers_instructeurs).to include(instructeur2)
    end
  end

  describe "#send_dossier_received" do
    let(:procedure) { create(:procedure) }
    let(:dossier) { create(:dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction)) }
    let(:instructeur) { create(:instructeur) }

    before do
      allow(NotificationMailer).to receive(:send_en_instruction_notification).and_return(double(deliver_later: nil))
    end

    it "sends an email when the dossier becomes en_instruction" do
      dossier.passer_en_instruction!(instructeur: instructeur)
      expect(NotificationMailer).to have_received(:send_en_instruction_notification).with(dossier)
    end

    it "does not an email when the dossier becomes accepte" do
      dossier.accepte!
      expect(NotificationMailer).to_not have_received(:send_en_instruction_notification)
    end
  end

  describe "#unspecified_attestation_champs" do
    let(:procedure) { create(:procedure, attestation_acceptation_template:, types_de_champ_public:, types_de_champ_private:) }
    let(:dossier) { create(:dossier, :en_instruction, procedure:) }

    let(:types_de_champ_public) { [tdc_1, tdc_2, tdc_3, tdc_4] }
    let(:types_de_champ_private) { [tdc_5, tdc_6, tdc_7, tdc_8] }

    let(:tdc_1) { { libelle: "specified champ-in-title" } }
    let(:tdc_2) { { libelle: "unspecified champ-in-title" } }
    let(:tdc_3) { { libelle: "specified champ-in-body" } }
    let(:tdc_4) { { libelle: "unspecified champ-in-body" } }
    let(:tdc_5) { { libelle: "specified annotation privée-in-title" } }
    let(:tdc_6) { { libelle: "unspecified annotation privée-in-title" } }
    let(:tdc_7) { { libelle: "specified annotation privée-in-body" } }
    let(:tdc_8) { { libelle: "unspecified annotation privée-in-body" } }

    before do
      (dossier.project_champs_public + dossier.project_champs_private)
        .filter { |c| c.libelle.match?(/^specified/) }
        .each { |c| c.update_attribute(:value, "specified") }
    end

    subject { dossier.unspecified_attestation_champs(AttestationTemplate.kinds.fetch(:acceptation)).map(&:libelle) }

    context "without attestation template" do
      let(:attestation_acceptation_template) { nil }

      it { is_expected.to eq([]) }
    end

    context "with attestation template v1" do
      # Test all combinations:
      # - with tag specified and unspecified
      # - with tag in body and tag in title
      # - with tag correponding to a champ and an annotation privée
      # - with a dash in the champ libelle / tag
      let(:title) { "voici --specified champ-in-title-- un --unspecified champ-in-title-- beau --specified annotation privée-in-title-- titre --unspecified annotation privée-in-title-- non --numéro du dossier--" }
      let(:body) { "voici --specified champ-in-body-- un --unspecified champ-in-body-- beau --specified annotation privée-in-body-- body --unspecified annotation privée-in-body-- non ?" }
      let(:attestation_acceptation_template) { build(:attestation_template, title: title, body: body, activated: activated) }

      context "which is disabled" do
        let(:activated) { false }

        it '', :slow do
          is_expected.to eq([])
        end
      end

      context "which is enabled" do
        let(:activated) { true }

        it do
          is_expected.to eq([
            "unspecified champ-in-title",
            "unspecified annotation privée-in-title",
            "unspecified champ-in-body",
            "unspecified annotation privée-in-body",
          ])
        end
      end
    end

    context "with attestation template v2" do
      # Test all combinations:
      # - with tag specified and unspecified
      # - with tag correponding to a champ and an annotation privée
      let(:body) {
        [
          { "type" => "mention", "attrs" => { "id" => "tdc#{procedure.types_de_champ_for_tags.find {  _1.libelle == "unspecified champ-in-body" }.stable_id}", "label" => "unspecified champ-in-body" } },
        ]
      }
      let(:attestation_acceptation_template) { build(:attestation_template, :v2) }

      before do
        tdc_content = (types_de_champ_public + types_de_champ_private).filter_map do |tdc_config|
          next if tdc_config[:libelle].include?("in-title")

          {
            "type" => "mention",
            "attrs" => { "id" => "tdc#{procedure.types_de_champ_for_tags.find { _1.libelle == tdc_config[:libelle] }.stable_id}", "label" => tdc_config[:libelle] },
          }
        end

        json_body = attestation_acceptation_template.json_body["content"]
        attestation_acceptation_template.json_body["content"][-1]["content"].concat(tdc_content)
        attestation_acceptation_template.save!
      end

      it do
        is_expected.to eq([
          "unspecified champ-in-body",
          "unspecified annotation privée-in-body",
        ])
      end
    end
  end

  describe '#build_attestation_acceptation' do
    let(:attestation_acceptation_template) { nil }
    let(:procedure) { create(:procedure, attestation_acceptation_template:) }

    before :each do
      dossier.attestation = dossier.build_attestation_acceptation
      dossier.reload
    end

    context 'when the dossier is in en_instruction state ' do
      let!(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }

      context 'when the procedure has no attestation' do
        it { expect(dossier.attestation).to be_nil }
      end

      context 'when the procedure has an unactivated attestation' do
        let(:attestation_acceptation_template) { build(:attestation_template, activated: false) }

        it { expect(dossier.attestation).to be_nil }
      end

      context 'when the procedure attached has an activated attestation' do
        let(:attestation_acceptation_template) { build(:attestation_template, activated: true) }

        it { expect(dossier.attestation).not_to be_nil }
      end
    end
  end

  describe 'updated_at' do
    let!(:dossier) { create(:dossier) }
    let(:modif_date) { Time.zone.parse('01/01/2100') }

    before { travel_to(modif_date) }

    subject do
      dossier.reload
      dossier.updated_at
    end

    it { is_expected.not_to eq(modif_date) }

    context 'when a champ is modified' do
      before { dossier.project_champs_public.first.update_attribute('value', 'yop') }

      it { is_expected.to eq(modif_date) }
    end

    context 'when a commentaire is modified' do
      before { dossier.commentaires << create(:commentaire) }

      it { is_expected.to eq(modif_date) }
    end

    context 'when an avis is modified' do
      before { dossier.avis << create(:avis) }

      it { is_expected.to eq(modif_date) }
    end
  end

  describe '#owner_name' do
    let(:procedure) { create(:procedure) }
    subject { dossier.owner_name }

    context 'when there is no entreprise or individual' do
      let(:dossier) { create(:dossier, individual: nil, procedure: procedure) }

      it { is_expected.to be_nil }
    end

    context 'when there is entreprise' do
      let(:dossier) { create(:dossier, :with_entreprise, procedure: procedure) }

      it { is_expected.to eq(dossier.etablissement.entreprise_raison_sociale) }
    end

    context 'when there is an individual' do
      let(:procedure) { create(:procedure, :for_individual) }
      let(:dossier) { create(:dossier, :with_individual, procedure: procedure) }

      it { is_expected.to eq("#{dossier.individual.nom} #{dossier.individual.prenom}") }
    end
  end

  describe "#hide_and_keep_track!" do
    let(:dossier) { create(:dossier, :en_construction) }
    let(:user) { dossier.user }
    let(:last_operation) { dossier.dossier_operation_logs.last }
    let(:reason) { :user_request }

    before do
      allow(DossierMailer).to receive(:notify_en_construction_deletion_to_administration).and_return(double(deliver_later: nil))
    end

    subject! { dossier.hide_and_keep_track!(user, reason) }

    context 'brouillon' do
      let(:dossier) { create(:dossier) }

      it 'hide the dossier' do
        expect(dossier.reload.hidden_by_user_at).to be_present
      end

      it 'does not records operation in the log' do
        expect(dossier.reload.dossier_operation_logs.last).to eq(nil)
      end
    end

    context 'en_construction' do
      it 'hide the dossier but does not discard' do
        expect(dossier.hidden_by_user_at).to be_present
      end

      it 'records the operation in the log' do
        expect(last_operation.operation).to eq("supprimer")
        expect(last_operation.automatic_operation?).to be_falsey
      end

      context 'where instructeurs are following the dossier' do
        let(:dossier) { create(:dossier, :en_construction, :followed) }
        let!(:non_following_instructeur) do
          non_following_instructeur = create(:instructeur)
          non_following_instructeur.groupe_instructeurs << dossier.procedure.defaut_groupe_instructeur
          non_following_instructeur
        end
      end

      context 'when dossier is brouillon' do
        let(:dossier) { create(:dossier) }
        it 'do not notifies the procedure administrateur' do
          expect(DossierMailer).not_to have_received(:notify_en_construction_deletion_to_administration)
        end
      end

      context 'with reason: user_removed' do
        let(:reason) { :user_removed }

        it 'hide the dossier' do
          expect(dossier.hidden_by_user_at).to be_present
        end

        it 'write the good reason to hidden_by_reason' do
          expect(dossier.hidden_by_reason).to eq("user_removed")
        end
      end

      context 'notifications to administration (en_construction)' do
        let(:procedure) { create(:procedure) }
        let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur]) }
        let(:dossier) { create(:dossier, :en_construction, groupe_instructeur:, procedure:) }
        let(:instructeur) { create(:instructeur) }

        context 'when the instructeur is not follower' do
          let!(:ip) { create(:instructeurs_procedure, instructeur:, procedure:, instant_email_dossier_deletion: true) }

          it "does not notify the instructeur" do
            dossier.hide_and_keep_track!(dossier.user, :user_request)

            expect(DossierMailer).not_to have_received(:notify_en_construction_deletion_to_administration).with(kind_of(Dossier), instructeur.email)
          end
        end

        context 'when the instructeur is follower and want to be notified' do
          let!(:ip) { create(:instructeurs_procedure, instructeur:, procedure:, instant_email_dossier_deletion: true) }

          before do
            dossier.followers_instructeurs << instructeur
          end

          it "notify the instructeur" do
            dossier.hide_and_keep_track!(dossier.user, :user_request)

            expect(DossierMailer).to have_received(:notify_en_construction_deletion_to_administration).with(kind_of(Dossier), instructeur.email)
          end
        end

        context "when an instructeur follower does not want to be notified" do
          let!(:ip) { create(:instructeurs_procedure, instructeur:, procedure:, instant_email_dossier_deletion: false) }

          before do
            dossier.followers_instructeurs << instructeur
          end

          it "does not notify the instructeur" do
            dossier.hide_and_keep_track!(dossier.user, :user_request)

            expect(DossierMailer).not_to have_received(:notify_en_construction_deletion_to_administration).with(kind_of(Dossier), instructeur.email)
          end
        end
      end
    end

    context 'termine' do
      let(:dossier) { create(:dossier, state: "accepte", hidden_by_administration_at: 1.hour.ago) }
      before { subject }

      it 'affect the right deletion reason to the dossier' do
        expect(dossier.hidden_by_reason).to eq("user_request")
      end

      context "when the instructeur hide the dossier" do
        let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [create(:instructeur)]) }
        let(:user) { create(:instructeur) }
        let(:reason) { :instructeur_request }

        context "when the dossier is already hidden by user" do
          let(:dossier) { create(:dossier, state: "accepte", groupe_instructeur:, hidden_by_user_at: Time.zone.yesterday) }

          it "creates dossier_suppression notification with correct delay" do
            subject
            expect(DossierNotification.count).to eq(1)

            notification = DossierNotification.last
            expect(notification.dossier_id).to eq(dossier.id)
            expect(notification.instructeur_id).to eq(groupe_instructeur.instructeur_ids.first)
            expect(notification.notification_type).to eq("dossier_suppression")
            expect(notification.display_at.to_date).to eq(Time.zone.now.to_date)
          end
        end

        context "when the dossier is not hidden by user" do
          let(:dossier) { create(:dossier, state: "accepte", groupe_instructeur:) }

          it "does not create dossier_suppression notification" do
            expect { subject }.not_to change { DossierNotification.count }
          end
        end
      end

      context "when the user hide the dossier" do
        let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [create(:instructeur)]) }

        context "when the dossier is already hidden by administration" do
          let(:dossier) { create(:dossier, state: "accepte", groupe_instructeur:, hidden_by_administration_at: Time.zone.yesterday) }

          it "creates dossier_suppression notification with correct delay" do
            subject
            expect(DossierNotification.count).to eq(1)

            notification = DossierNotification.last
            expect(notification.dossier_id).to eq(dossier.id)
            expect(notification.instructeur_id).to eq(groupe_instructeur.instructeur_ids.first)
            expect(notification.notification_type).to eq("dossier_suppression")
            expect(notification.display_at.to_date).to eq(Time.zone.now.to_date)
          end
        end

        context "when the dossier is not hidden by administration" do
          let(:dossier) { create(:dossier, state: "accepte", groupe_instructeur:) }

          it "does not create dossier_suppression notification" do
            expect { subject }.not_to change { DossierNotification.count }
          end
        end
      end
    end
  end

  describe 'webhook' do
    let(:dossier) { create(:dossier) }
    let(:instructeur) { create(:instructeur) }

    it 'should not call webhook' do
      expect {
        dossier.accepte!
      }.to_not have_enqueued_job(WebHookJob)
    end

    it 'should not call webhook with empty value' do
      dossier.procedure.update_column(:web_hook_url, '')

      expect {
        dossier.accepte!
      }.to_not have_enqueued_job(WebHookJob)
    end

    it 'should not call webhook with blank value' do
      dossier.procedure.update_column(:web_hook_url, '   ')

      expect {
        dossier.accepte!
      }.to_not have_enqueued_job(WebHookJob)
    end

    it 'should call webhook' do
      dossier.procedure.update_column(:web_hook_url, '/webhook.json')

      expect {
        dossier.update_column(:conservation_extension, 'P1W')
      }.to_not have_enqueued_job(WebHookJob)

      expect {
        dossier.passer_en_construction!
      }.to have_enqueued_job(WebHookJob).with(dossier.procedure.id, dossier.id, 'en_construction', anything)

      expect {
        dossier.update_column(:conservation_extension, 'P2W')
      }.to_not have_enqueued_job(WebHookJob)

      expect {
        dossier.passer_en_instruction!(instructeur: instructeur)
      }.to have_enqueued_job(WebHookJob).with(dossier.procedure.id, dossier.id, 'en_instruction', anything)
    end
  end

  describe "#can_transition_to_en_construction?" do
    let(:procedure) { create(:procedure, :published) }
    let(:dossier) { create(:dossier, state: state, procedure: procedure) }

    subject { dossier.can_transition_to_en_construction? }

    context "dossier state is brouillon" do
      let(:state) { Dossier.states.fetch(:brouillon) }
      it { is_expected.to be true }

      context "procedure is closed" do
        before { procedure.close! }
        it { is_expected.to be false }
      end
    end

    context "dossier state is en_construction" do
      let(:state) { Dossier.states.fetch(:en_construction) }
      it { is_expected.to be false }
    end

    context "dossier state is en_instruction" do
      let(:state) { Dossier.states.fetch(:en_instruction) }
      it { is_expected.to be false }
    end

    context "dossier state is en_instruction" do
      let(:state) { Dossier.states.fetch(:accepte) }
      it { is_expected.to be false }
    end

    context "dossier state is en_instruction" do
      let(:state) { Dossier.states.fetch(:refuse) }
      it { is_expected.to be false }
    end

    context "dossier state is en_instruction" do
      let(:state) { Dossier.states.fetch(:sans_suite) }
      it { is_expected.to be false }
    end
  end

  describe "#messagerie_available?" do
    let(:procedure) { create(:procedure) }
    let(:dossier) { create(:dossier, procedure: procedure) }

    subject { dossier.messagerie_available? }

    context "dossier is brouillon" do
      before { dossier.state = Dossier.states.fetch(:brouillon) }

      it { is_expected.to be false }
    end

    context "dossier is submitted" do
      before { dossier.state = Dossier.states.fetch(:en_instruction) }

      it { is_expected.to be true }
    end

    context "dossier is archived" do
      before { dossier.archived = true }

      it { is_expected.to be false }
    end
  end

  describe '#accepter!' do
    let(:dossier) { create(:dossier, :en_instruction, :with_individual) }
    let(:last_operation) { dossier.dossier_operation_logs.last }
    let(:operation_serialized) { last_operation.data }
    let!(:instructeur) { create(:instructeur) }
    let!(:now) { Time.zone.parse('01/01/2100') }
    let(:attestation) { Attestation.new }

    before do
      allow(NotificationMailer).to receive(:send_accepte_notification).and_return(double(deliver_later: true))
      allow(dossier).to receive(:build_attestation_acceptation).and_return(attestation)

      travel_to now
      dossier.accepter!(instructeur: instructeur, motivation: 'motivation')
      dossier.reload
    end

    it "update attributes" do
      expect(dossier.traitements.last.motivation).to eq('motivation')
      expect(dossier.motivation).to eq('motivation')
      expect(dossier.traitements.last.instructeur_email).to eq(instructeur.email)
      expect(dossier.en_instruction_at).to eq(dossier.en_instruction_at)
      expect(dossier.traitements.last.processed_at).to eq(now)
      expect(dossier.processed_at).to eq(now)
      expect(dossier.state).to eq('accepte')
      expect(last_operation.operation).to eq('accepter')
      expect(last_operation.automatic_operation?).to be_falsey
      expect(operation_serialized['operation']).to eq('accepter')
      expect(operation_serialized['dossier_id']).to eq(dossier.id)
      expect(operation_serialized['executed_at']).to eq(last_operation.executed_at.iso8601)
      expect(NotificationMailer).to have_received(:send_accepte_notification).with(dossier)
      expect(dossier.attestation).to eq(attestation)
      expect(dossier.commentaires.count).to eq(1)
    end
  end

  describe '#accepter_automatiquement!' do
    let(:last_operation) { dossier.dossier_operation_logs.last }
    let!(:now) { Time.zone.parse('01/01/2100') }
    let(:attestation) { Attestation.new }

    before do
      allow(NotificationMailer).to receive(:send_accepte_notification).and_return(double(deliver_later: true))
      allow(dossier).to receive(:build_attestation_acceptation).and_return(attestation)

      travel_to(now)
    end

    subject {
      dossier.accepter_automatiquement!
      dossier.reload
    }

    context 'as declarative procedure' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_declarative_accepte) }

      it 'accepts dossier automatiquement' do
        expect(subject.motivation).to eq(nil)
        expect(subject.en_instruction_at).to eq(now)
        expect(subject.processed_at).to eq(now)
        expect(subject.declarative_triggered_at).to eq(now)
        expect(subject.sva_svr_decision_triggered_at).to be_nil
        expect(subject).to be_accepte
        expect(last_operation.operation).to eq('accepter')
        expect(last_operation.automatic_operation?).to be_truthy
        expect(NotificationMailer).to have_received(:send_accepte_notification).with(dossier)
        expect(subject.attestation).to eq(attestation)
      end
    end

    context 'as sva procedure' do
      let(:procedure) { create(:procedure, :for_individual, :published, :sva) }
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: Date.current, en_instruction_at: DateTime.new(2021, 5, 1, 12)) }

      it 'accepts dossier automatiquement' do
        expect(subject.motivation).to eq(nil)
        expect(subject.en_instruction_at).to eq(DateTime.new(2021, 5, 1, 12))
        expect(subject.processed_at).to eq(now)
        expect(subject.declarative_triggered_at).to be_nil
        expect(subject.sva_svr_decision_triggered_at).to eq(now)
        expect(subject).to be_accepte
        expect(last_operation.operation).to eq('accepter')
        expect(last_operation.automatic_operation?).to be_truthy
        expect(NotificationMailer).to have_received(:send_accepte_notification).with(dossier)
        expect(subject.attestation).to eq(attestation)
        expect(dossier.commentaires.count).to eq(1)
      end
    end
  end

  describe '#refuser_automatiquement' do
    context 'as svr procedure' do
      let(:last_operation) { dossier.dossier_operation_logs.last }
      let(:procedure) { create(:procedure, :for_individual, :published, :svr) }
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: Date.current, en_instruction_at: DateTime.new(2021, 5, 1, 12)) }

      before {
        freeze_time
        allow(NotificationMailer).to receive(:send_refuse_notification).and_return(double(deliver_later: true))
      }

      subject {
        dossier.refuser_automatiquement!
        dossier.reload
      }

      it 'refuses dossier automatiquement' do
        expect(subject.en_instruction_at).to eq(DateTime.new(2021, 5, 1, 12))
        expect(subject.processed_at).to eq(Time.current)
        expect(subject.declarative_triggered_at).to be_nil
        expect(subject.sva_svr_decision_triggered_at).to eq(Time.current)
        expect(subject.motivation).to include("dans le délai imparti")
        expect(subject).to be_refuse
        expect(last_operation.operation).to eq('refuser')
        expect(last_operation.automatic_operation?).to be_truthy
        expect(NotificationMailer).to have_received(:send_refuse_notification).with(dossier)
        expect(subject.attestation).to be_nil
        expect(dossier.commentaires.count).to eq(1)
      end

      context 'for an user having english locale' do
        before { dossier.user.update!(locale: 'en') }

        it 'translates the motivation' do
          expect(subject.motivation).to include('within the time limit')
        end
      end
    end
  end

  describe '#passer_en_instruction!' do
    let(:dossier) { create(:dossier, :en_construction, en_construction_close_to_expiration_notice_sent_at: Time.zone.now) }
    let(:last_operation) { dossier.dossier_operation_logs.last }
    let(:operation_serialized) { last_operation.data }
    let(:instructeur) { create(:instructeur) }
    let!(:correction) { create(:dossier_correction, dossier:) } # correction has a commentaire

    subject(:passer_en_instruction) { dossier.passer_en_instruction!(instructeur: instructeur) }

    it do
      passer_en_instruction

      expect(dossier.state).to eq('en_instruction')
      expect(dossier.followers_instructeurs).to include(instructeur)
      expect(dossier.en_construction_close_to_expiration_notice_sent_at).to be_nil
      expect(last_operation.operation).to eq('passer_en_instruction')
      expect(last_operation.automatic_operation?).to be_falsey
      expect(operation_serialized['operation']).to eq('passer_en_instruction')
      expect(operation_serialized['dossier_id']).to eq(dossier.id)
      expect(operation_serialized['executed_at']).to eq(last_operation.executed_at.iso8601)
    end

    it "resolves pending correction and creates commentaire with expected wording" do
      expect { passer_en_instruction }.to change { dossier.commentaires.count }.by(1)

      expect(dossier.pending_correction?).to be_falsey
      expect(correction.reload.resolved_at).to be_present

      email_template = dossier.procedure.email_template_for(dossier.state)
      commentaire = dossier.commentaires.last

      expect(commentaire.body).to include(sanitize(email_template.subject_for_dossier(dossier)), sanitize(email_template.body_for_dossier(dossier)))
      expect(commentaire.dossier).to eq(dossier)
    end
  end

  describe '#passer_automatiquement_en_instruction!' do
    let(:last_operation) { dossier.dossier_operation_logs.last }
    let(:operation_serialized) { last_operation.data }
    let(:instructeur) { create(:instructeur) }

    context "via procedure declarative en instruction" do
      let(:dossier) { create(:dossier, :en_construction, :with_declarative_en_instruction, en_construction_close_to_expiration_notice_sent_at: Time.zone.now) }

      subject do
        dossier.process_declarative!
        dossier.reload
      end

      it 'passes dossier en instruction' do
        expect(subject.followers_instructeurs).not_to include(instructeur)
        expect(subject.en_construction_close_to_expiration_notice_sent_at).to be_nil
        expect(subject.declarative_triggered_at).to be_within(1.second).of(Time.current)
        expect(last_operation.operation).to eq('passer_en_instruction')
        expect(last_operation.automatic_operation?).to be_truthy
        expect(operation_serialized['operation']).to eq('passer_en_instruction')
        expect(operation_serialized['dossier_id']).to eq(dossier.id)
        expect(operation_serialized['executed_at']).to eq(last_operation.executed_at.iso8601)
        expect(dossier.commentaires.count).to eq(1)
      end
    end

    context "via procedure sva" do
      let(:procedure) { create(:procedure, :sva, :published, :for_individual) }
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now) }
      let(:sva_svr_decision_on) { SVASVRDecisionDateCalculatorService.new(dossier, procedure).decision_date }

      subject do
        dossier.process_sva_svr!
        dossier.reload
      end

      it 'passes dossier en instruction' do
        expect(subject.state).to eq('en_instruction')
        expect(subject.followers_instructeurs).not_to include(instructeur)
        expect(subject.sva_svr_decision_on).to eq(sva_svr_decision_on)
        expect(last_operation.operation).to eq('passer_en_instruction')
        expect(last_operation.automatic_operation?).to be_truthy
        expect(operation_serialized['operation']).to eq('passer_en_instruction')
        expect(operation_serialized['dossier_id']).to eq(dossier.id)
        expect(operation_serialized['executed_at']).to eq(last_operation.executed_at.iso8601)
      end

      context 'when dossier was submitted with sva not yet enabled' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, depose_at: 10.days.ago) }

        it 'leaves dossier en construction' do
          expect(subject.sva_svr_decision_on).to be_nil
          expect(subject.state).to eq('en_construction')
        end
      end
    end
  end

  describe '#can_repasser_en_construction?' do
    let(:dossier) { create(:dossier, :en_instruction) }
    it { expect(dossier.can_repasser_en_construction?).to be_truthy }

    context 'when procedure is sva' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: create(:procedure, :sva)) }

      it { expect(dossier.can_repasser_en_construction?).to be_falsey }
    end
  end

  describe '#can_passer_en_instruction?' do
    let(:dossier) { create(:dossier, :en_construction) }

    it { expect(dossier.can_passer_en_instruction?).to be_truthy }

    context 'when there is a pending correction' do
      before { create(:dossier_correction, dossier:) }

      it { expect(dossier.can_passer_en_instruction?).to be_truthy }
    end

    context 'when there is a pending correction with procedure blocking_pending_correction feature' do
      let(:resolved_at) { nil }

      before do
        Flipper.enable(:blocking_pending_correction, dossier.procedure)
        create(:dossier_correction, dossier:, resolved_at: resolved_at)
      end

      it { expect(dossier.can_passer_en_instruction?).to be_falsey }

      context 'when there is a resolved correction' do
        let(:resolved_at) { Time.current }

        it { expect(dossier.can_passer_en_instruction?).to be_truthy }
      end
    end
  end

  describe '#can_passer_automatiquement_en_instruction?' do
    let(:dossier) { create(:dossier, :en_construction, declarative_triggered_at: declarative_triggered_at) }
    let(:declarative_triggered_at) { nil }

    it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_falsey }

    context 'when dossier is declarative' do
      before { dossier.procedure.update(declarative_with_state: :en_instruction) }

      context 'when dossier never transitioned' do
        it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_truthy }
      end

      context 'when dossier transitioned before' do
        let(:declarative_triggered_at) { 1.day.ago }

        it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_falsey }
      end
    end

    context 'when procedure has auto archive set' do
      before { dossier.procedure.update(auto_archive_on: 1.day.ago) }

      it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_truthy }

      context 'when auto_archive_on is in the future' do
        before { dossier.procedure.update(auto_archive_on: 1.day.from_now) }

        it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_falsey }
      end

      context 'when dossier transitioned before' do
        let(:declarative_triggered_at) { 1.day.ago }

        it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_truthy }
      end

      context 'when there are pending correction' do
        before { create(:dossier_correction, dossier:) }

        it "can't passe en instruction" do
          expect(dossier.can_passer_automatiquement_en_instruction?).to be_falsey
          expect(dossier.pending_correction?).to be_truthy
        end
      end
    end

    context 'when procedure has sva or svr enabled' do
      let(:procedure) { create(:procedure, :published, :sva) }
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_truthy }

      context 'when dossier was already processed by sva' do
        let(:dossier) { create(:dossier, :en_construction, procedure:, sva_svr_decision_triggered_at: 1.hour.ago) }

        it { expect(dossier.can_passer_automatiquement_en_instruction?).to be_falsey }
      end
    end
  end

  describe '#can_accepter_automatiquement?' do
    let(:dossier) { create(:dossier, state: initial_state, declarative_triggered_at: declarative_triggered_at) }
    let(:initial_state) { :en_construction }
    let(:declarative_triggered_at) { nil }

    it { expect(dossier.can_accepter_automatiquement?).to be_falsey }

    context 'when dossier is declarative' do
      before { dossier.procedure.update(declarative_with_state: :accepte) }

      context 'when dossier never transitioned' do
        it { expect(dossier.can_accepter_automatiquement?).to be_truthy }
      end

      context 'when dossier transitioned before' do
        let(:declarative_triggered_at) { 1.day.ago }

        it { expect(dossier.can_accepter_automatiquement?).to be_falsey }
      end
    end

    context 'when procedure is sva/svr' do
      let(:decision) { :sva }
      let(:initial_state) { :en_instruction }

      before do
        dossier.procedure.update!(sva_svr: SVASVRConfiguration.new(decision:).attributes)
        dossier.update!(sva_svr_decision_on: Date.current)
      end

      it { expect(dossier.can_accepter_automatiquement?).to be_truthy }

      context 'when sva_svr_decision_on is in the future' do
        before { dossier.update!(sva_svr_decision_on: 1.day.from_now) }

        it { expect(dossier.can_accepter_automatiquement?).to be_falsey }
      end

      context 'when dossier has pending correction' do
        let(:dossier) { create(:dossier, :en_construction) }
        let!(:dossier_correction) { create(:dossier_correction, dossier:) }

        it { expect(dossier.can_accepter_automatiquement?).to be_falsey }
      end

      context 'when decision is svr' do
        let(:decision) { :svr }

        it { expect(dossier.can_accepter_automatiquement?).to be_falsey }
      end

      context 'when dossier was already processed by sva' do
        before { dossier.update!(sva_svr_decision_triggered_at: 1.hour.ago) }

        it { expect(dossier.can_accepter_automatiquement?).to be_falsey }
      end
    end
  end

  describe '#can_refuser_automatiquement?' do
    let(:dossier) { create(:dossier, state: initial_state) }
    let(:initial_state) { :en_instruction }

    it { expect(dossier.can_refuser_automatiquement?).to be_falsey }

    context 'when procedure is sva/svr' do
      let(:decision) { :svr }

      before do
        dossier.procedure.update!(sva_svr: SVASVRConfiguration.new(decision:).attributes)
        dossier.update!(sva_svr_decision_on: Date.current)
      end

      it { expect(dossier.can_refuser_automatiquement?).to be_truthy }

      context 'when procedure is svr' do
        let(:decision) { :svr }

        before do
          dossier.procedure.update!(sva_svr: SVASVRConfiguration.new(decision:).attributes)
          dossier.update!(sva_svr_decision_on: Date.current)
        end

        it { expect(dossier.can_refuser_automatiquement?).to be_truthy }

        context 'when sva_svr_decision_on is in the future' do
          before { dossier.update!(sva_svr_decision_on: 1.day.from_now) }

          it { expect(dossier.can_refuser_automatiquement?).to be_falsey }
        end

        context 'when dossier has pending correction' do
          let(:dossier) { create(:dossier, :en_construction) }
          let!(:dossier_correction) { create(:dossier_correction, dossier:) }

          it { expect(dossier.can_refuser_automatiquement?).to be_falsey }
        end

        context 'when decision is sva' do
          let(:decision) { :sva }

          it { expect(dossier.can_refuser_automatiquement?).to be_falsey }
        end

        context 'when dossier was already processed by svr' do
          before { dossier.update!(sva_svr_decision_triggered_at: 1.hour.ago) }

          it { expect(dossier.can_refuser_automatiquement?).to be_falsey }
        end
      end
    end
  end

  describe "can't transition to terminer when etablissement is in degraded mode" do
    let(:instructeur) { create(:instructeur) }
    let(:motivation) { 'motivation' }

    context "when dossier is en_instruction" do
      let(:dossier_incomplete) { create(:dossier, :en_instruction, :with_entreprise, as_degraded_mode: true) }
      let(:dossier_ok) { create(:dossier, :en_instruction, :with_entreprise, as_degraded_mode: false) }

      it "can't accepter" do
        expect(dossier_incomplete.may_accepter?(instructeur:, motivation:)).to be_falsey
        expect(dossier_ok.accepter(instructeur:, motivation:)).to be_truthy
      end

      it "can't refuser" do
        expect(dossier_incomplete.may_refuser?(instructeur:, motivation:)).to be_falsey
        expect(dossier_ok.may_refuser?(instructeur:, motivation:)).to be_truthy
      end

      it "can't classer_sans_suite" do
        expect(dossier_incomplete.may_classer_sans_suite?(instructeur:, motivation:)).to be_falsey
        expect(dossier_ok.may_classer_sans_suite?(instructeur:, motivation:)).to be_truthy
      end
    end

    context "when dossier is en_construction" do
      let(:dossier_incomplete) { create(:dossier, :en_construction, :with_entreprise, :with_declarative_accepte, as_degraded_mode: true) }
      let(:dossier_ok) { create(:dossier, :en_construction, :with_entreprise, :with_declarative_accepte, as_degraded_mode: false) }

      it "can't accepter_automatiquement" do
        expect(dossier_incomplete.may_accepter_automatiquement?(instructeur:, motivation:)).to be_falsey
        expect(dossier_ok.accepter_automatiquement(instructeur:, motivation:)).to be_truthy
      end
    end

    context "when a SIRET champ has etablissement in degraded mode" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
      let(:dossier_incomplete) { create(:dossier, :en_instruction, :with_populated_champs, procedure:) }
      let(:dossier_ok) { create(:dossier, :en_instruction, :with_populated_champs, procedure:) }

      before do
        dossier_incomplete.champs.first.update(etablissement: Etablissement.new(siret: build(:etablissement).siret))
      end

      it "can't accepter" do
        expect(dossier_incomplete.may_accepter?(instructeur:, motivation:)).to be_falsey
        expect(dossier_ok.may_accepter?(instructeur:, motivation:)).to be_truthy
      end
    end
  end

  describe "can't transition to terminer when annotations privees are not valid" do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, types_de_champ_private:) }
    let(:dossier_incomplete) { create(:dossier, :en_instruction, procedure:) }
    let(:dossier_ok) { create(:dossier, :en_instruction, :with_populated_annotations, procedure:) }
    let(:types_de_champ_private) { [{ type: :text, mandatory: true }] }

    context "when dossier is en_instruction" do
      it "can't accepter" do
        expect(dossier_incomplete.may_accepter?(instructeur:)).to be_falsey
        expect(dossier_ok.accepter(instructeur:)).to be_truthy
      end
    end
  end

  describe "#check_mandatory_and_visible_champs_public" do
    include Logic

    let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:types_de_champ) { [type_de_champ].compact }
    let(:type_de_champ) { nil }
    let(:errors) { dossier.check_mandatory_and_visible_champs_public }

    it 'no mandatory champs' do
      expect(errors).to be_empty
    end

    context "with mandatory champs" do
      let(:type_de_champ) { { mandatory: true } }
      let(:champ_with_error) { dossier.champs.first }

      before do
        champ_with_error.value = nil
        champ_with_error.save
      end

      it 'should have errors' do
        expect(errors).not_to be_empty
        expect(errors.first.full_message).to eq("Le champ « Value » doit être rempli")
      end

      context "conditionaly visible" do
        let(:types_de_champ) { [{ type: :yes_no, stable_id: 99, mandatory: false }, type_de_champ] }
        let(:type_de_champ) { { mandatory: true, condition: ds_eq(champ_value(99), constant(true)) } }

        it 'should not have errors' do
          expect(errors).to be_empty
        end
      end
    end

    context "with mandatory SIRET champ" do
      let(:type_de_champ) { { type: :siret, mandatory: true } }
      let(:champ_siret) { dossier.champs.first }

      before do
        champ_siret.update(value: '44011762001530')
      end

      it 'should not have errors' do
        expect(errors).to be_empty
      end

      context "and invalid SIRET" do
        before do
          champ_siret.update(value: "1234")
          dossier.reload
        end

        it 'should have errors' do
          expect(errors).not_to be_empty
          expect(errors.first.full_message).to eq("Le champ « Value » doit être rempli")
        end
      end
    end

    context "with champ repetition" do
      let(:type_de_champ) { { type: :repetition, mandatory: true, children: [{ mandatory: true }] } }
      let(:revision) { procedure.active_revision }
      let(:type_de_champ_repetition) { revision.types_de_champ.first }

      context "when no champs" do
        it 'should have errors' do
          dossier.champs.first.row_ids.each do |row_id|
            dossier.repetition_remove_row(type_de_champ_repetition, row_id, updated_by: 'test')
          end
          expect(dossier.champs.first.rows).to be_empty
          expect(errors).not_to be_empty
          expect(errors.first.full_message).to eq("Le champ « Value » doit être rempli")
        end
      end

      context "when mandatory champ inside repetition" do
        it 'should have errors' do
          expect(dossier.champs.first.rows).not_to be_empty
          expect(errors).not_to be_empty
          expect(errors.first.full_message).to eq("Le champ « Value » doit être rempli")
        end

        context "conditionaly visible" do
          let(:types_de_champ) { [{ type: :yes_no, stable_id: 99, mandatory: false }, type_de_champ] }
          let(:type_de_champ) { { type: :repetition, mandatory: true, children: [{ mandatory: true }], condition: ds_eq(champ_value(99), constant(true)) } }

          it 'should not have errors' do
            expect(dossier.champs.second.rows).not_to be_empty
            expect(errors).to be_empty
          end

          it 'should have errors' do
            dossier.champs.first.update(value: 'true')
            expect(dossier.champs.second.rows).not_to be_empty
            expect(errors).not_to be_empty
            expect(errors.first.full_message).to eq("Le champ « Value » doit être rempli")
          end
        end
      end
    end
  end

  describe "check simple mode options for formatted champ" do
    let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:types_de_champ) { [type_de_champ] }
    let(:type_de_champ) { { type: :formatted, formatted_mode: 'simple', letters_accepted:, numbers_accepted:, special_characters_accepted:, min_character_length:, max_character_length: } }
    let(:letters_accepted) { '1' }
    let(:numbers_accepted) { '1' }
    let(:special_characters_accepted) { '1' }
    let(:min_character_length) { "" }
    let(:max_character_length) { "" }

    before do
      champ = dossier.project_champs_public.first
      champ.value = value
      dossier.save(context: :champs_public_value)
    end

    context 'with letters forbidden' do
      let(:letters_accepted) { '0' }

      context 'with valid value' do
        let(:value) { '1234*' }
        it 'should have no error' do
          expect(dossier.errors).to be_empty
        end
      end

      context 'with invalid value' do
        let(:value) { 'azerlkj' }
        it 'should have errors' do
          expect(dossier.errors.map(&:type)).to eq [:letters_forbidden]
        end
      end
    end

    context 'with only letters accepted' do
      let(:letters_accepted) { '1' }
      let(:numbers_accepted) { '0' }
      let(:special_characters_accepted) { '0' }

      context 'with valid value' do
        let(:value) { 'oupsàèœÅ' }
        it 'should have no error' do
          expect(dossier.errors).to be_empty
        end
      end

      context 'with invalid value' do
        let(:value) { '123ab*' }
        it 'should have errors' do
          expect(dossier.errors.map(&:type)).to match_array [:numbers_forbidden, :special_characters_forbidden]
        end
      end
    end

    context 'with numbers forbidden' do
      let(:numbers_accepted) { '0' }

      context 'with valid value' do
        let(:value) { 'azer*' }
        it 'should have no error' do
          expect(dossier.errors).to be_empty
        end
      end

      context 'with invalid value' do
        let(:value) { '1234' }
        it 'should have errors' do
          expect(dossier.errors).not_to be_empty
        end
      end
    end

    context 'with special characters forbidden' do
      let(:special_characters_accepted) { '0' }

      context 'with valid value' do
        let(:value) { 'azer123' }
        it 'should have no error' do
          expect(dossier.errors).to be_empty
        end
      end

      context 'with invalid value' do
        let(:value) { '*1234' }
        it 'should have errors' do
          expect(dossier.errors).not_to be_empty
        end
      end
    end

    context 'with min charachter length' do
      let(:min_character_length) { '3' }

      context 'with valid value' do
        let(:value) { 'az*er123' }
        it 'should have no error' do
          expect(dossier.errors).to be_empty
        end
      end

      context 'with invalid value' do
        let(:value) { '*1' }
        it 'should have errors' do
          expect(dossier.errors).not_to be_empty
        end
      end
    end

    context 'with max charachter length' do
      let(:max_character_length) { '3' }

      context 'with valid value' do
        let(:value) { 'az*' }
        it 'should have no error' do
          expect(dossier.errors).to be_empty
        end
      end

      context 'with invalid value' do
        let(:value) { '*1az' }
        it 'should have errors' do
          expect(dossier.errors).not_to be_empty
        end
      end
    end
  end

  describe "check advanced mode options for formatted champ" do
    let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:types_de_champ) { [type_de_champ] }
    let(:type_de_champ) { { type: :formatted, formatted_mode: 'advanced', expression_reguliere:, expression_reguliere_exemple_text:, expression_reguliere_error_message: } }

    context "with bad example" do
      let(:expression_reguliere_exemple_text) { "01234567" }
      let(:expression_reguliere) { "[A-Z]+" }
      let(:expression_reguliere_error_message) { "Le champ doit être composé de lettres majuscules" }

      before do
        champ = dossier.project_champs_public.first
        champ.value = expression_reguliere_exemple_text
        dossier.save(context: :champs_public_value)
      end

      it 'should have errors' do
        expect(dossier.errors).not_to be_empty
        expect(dossier.errors.full_messages.join(',')).to include(dossier.project_champs_public.first.expression_reguliere_error_message)
      end
    end

    context "with good example" do
      let(:expression_reguliere_exemple_text) { "AZERTY" }
      let(:expression_reguliere) { "[A-Z]+" }
      let(:expression_reguliere_error_message) { "Le champ doit être composé de lettres majuscules" }

      before do
        champ = dossier.project_champs_public.first
        champ.value = expression_reguliere_exemple_text
        dossier.save
      end

      it 'should not have errors' do
        expect(dossier.errors).to be_empty
      end
    end
  end

  describe 'index_for_section_header' do
    let(:types_de_champ_public) { [{ type: :repetition, mandatory: true, children: [{ type: :header_section }] }] }
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:header_in_repetition) { dossier.revision.types_de_champ.find(&:header_section?) }

    it 'index classly' do
      expect(dossier.index_for_section_header(header_in_repetition)).to eq("1.1")
    end
  end

  describe '#repasser_en_instruction!' do
    let(:dossier) { create(:dossier, :refuse, :with_attestation_acceptation, :with_justificatif, archived: true, termine_close_to_expiration_notice_sent_at: Time.zone.now, sva_svr_decision_on: 1.day.ago) }
    let!(:instructeur) { create(:instructeur) }
    let(:last_operation) { dossier.dossier_operation_logs.last }

    before do
      freeze_time
      allow(NotificationMailer).to receive(:send_repasser_en_instruction_notification).and_return(double(deliver_later: true))
      dossier.repasser_en_instruction!(instructeur: instructeur)
      dossier.reload
    end

    it "update attributes" do
      expect(dossier.state).to eq('en_instruction')
      expect(dossier.archived).to be_falsey
      expect(dossier.motivation).to be_nil
      expect(dossier.justificatif_motivation.attached?).to be_falsey
      expect(dossier.attestation).to be_nil
      expect(dossier.sva_svr_decision_on).to be_nil
      expect(dossier.termine_close_to_expiration_notice_sent_at).to be_nil
      expect(last_operation.operation).to eq('repasser_en_instruction')
      expect(last_operation.data['author']['email']).to eq(instructeur.email)
      expect(NotificationMailer).to have_received(:send_repasser_en_instruction_notification).with(dossier)
    end
  end

  describe '#notify_draft_not_submitted' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:procedure_near_closing) { create(:procedure, :published, auto_archive_on: Time.zone.today + Dossier::REMAINING_DAYS_BEFORE_CLOSING.days) }
    let!(:procedure_closed_later) { create(:procedure, :published, auto_archive_on: Time.zone.today + Dossier::REMAINING_DAYS_BEFORE_CLOSING.days + 1.day) }
    let!(:procedure_closed_before) { create(:procedure, :published, auto_archive_on: Time.zone.today + Dossier::REMAINING_DAYS_BEFORE_CLOSING.days - 1.day) }

    # user 1 has three draft dossiers where one is for procedure that closes in two days ==> should trigger one mail
    let!(:draft_near_closing) { create(:dossier, user: user1, procedure: procedure_near_closing) }
    let!(:draft_before) { create(:dossier, user: user1, procedure: procedure_closed_before) }
    let!(:draft_later) { create(:dossier, user: user1, procedure: procedure_closed_later) }

    # user 2 submitted a draft and en_construction dossier for the same procedure ==> should not trigger the mail
    let!(:draft_near_closing_2) { create(:dossier, :en_construction, user: user2, procedure: procedure_near_closing) }
    let!(:submitted_near_closing_2) { create(:dossier, user: user2, procedure: procedure_near_closing) }

    before do
      allow(DossierMailer).to receive(:notify_brouillon_not_submitted).and_return(double(deliver_later: nil))
      Dossier.notify_draft_not_submitted
    end

    it 'notifies draft is not submitted' do
      expect(DossierMailer).to have_received(:notify_brouillon_not_submitted).once
      expect(DossierMailer).to have_received(:notify_brouillon_not_submitted).with(draft_near_closing)
    end
  end

  describe '#geo_position' do
    let(:lat) { "46.538192" }
    let(:lon) { "2.428462" }
    let(:zoom) { "13" }

    let(:etablissement_geo_adresse_lat) { "40.7143528" }
    let(:etablissement_geo_adresse_lon) { "-74.0059731" }

    let(:result) { { lat: lat, lon: lon, zoom: zoom } }
    let(:dossier) { create(:dossier) }

    it 'should geolocate' do
      expect(dossier.geo_position).to eq(result)
    end

    context 'with etablissement' do
      before do
        Geocoder::Lookup::Test.add_stub(
          dossier.etablissement.geo_adresse, [
            {
              'coordinates' => [etablissement_geo_adresse_lat.to_f, etablissement_geo_adresse_lon.to_f],
            },
          ]
        )
      end

      let(:dossier) { create(:dossier, :with_entreprise) }
      let(:result) { { lat: etablissement_geo_adresse_lat, lon: etablissement_geo_adresse_lon, zoom: zoom } }

      it 'should geolocate' do
        expect(dossier.geo_position).to eq(result)
      end
    end
  end

  describe '#geo_data' do
    let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
    let(:dossier) { create(:dossier, :with_populated_champs, :with_populated_annotations, procedure:) }
    let(:types_de_champ_public) { [] }
    let(:types_de_champ_private)  { [] }

    context "without data" do
      it { expect(dossier.geo_data?).to be_falsey }
    end

    context "with geo data in public champ" do
      let(:types_de_champ_public) { [{ type: :carte }] }

      it { expect(dossier.geo_data?).to be_truthy }
    end

    context "with geo data in private champ" do
      let(:types_de_champ_private) { [{ type: :carte }] }

      it { expect(dossier.geo_data?).to be_truthy }
    end

    context "should solve N+1 problem" do
      let(:types_de_champ_public) { [{ type: :carte }, { type: :carte }, { type: :carte }] }

      it do
        dossier.filled_champs

        count = 0

        callback = lambda { |*_args| count += 1 }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          dossier.geo_data?
        end

        expect(count).to eq(1)
      end
    end
  end

  describe 'dossier_operation_log after dossier deletion' do
    let(:dossier) { create(:dossier) }
    let(:dossier_operation_log) { create(:dossier_operation_log, dossier: dossier) }

    it 'should nullify dossier link' do
      expect(dossier_operation_log.dossier).to eq(dossier)
      expect(DossierOperationLog.count).to eq(1)
      dossier.destroy
      expect(dossier_operation_log.reload.dossier).to be_nil
      expect(DossierOperationLog.count).to eq(1)
    end
  end

  describe 'brouillon_expired and en_construction_expired' do
    let(:administrateur) { administrateurs(:default_admin) }
    let(:user) { administrateur.user }
    let(:reason) { DeletedDossier.reasons.fetch(:user_request) }

    before do
      create(:dossier, user: user)
      create(:dossier, :en_construction, user: user)
      create(:dossier, user: user).hide_and_keep_track!(user, reason)
      create(:dossier, :en_construction, user: user).hide_and_keep_track!(user, reason)

      travel_to(2.months.ago) do
        create(:dossier, user: user).hide_and_keep_track!(user, reason)
        create(:dossier, :en_construction, user: user).hide_and_keep_track!(user, reason)

        create(:dossier, user: user).procedure.discard_and_keep_track!(administrateur)
        create(:dossier, :en_construction, user: user).procedure.discard_and_keep_track!(administrateur)
      end

      travel_to(2.weeks.ago) do
        create(:dossier, user: user).hide_and_keep_track!(user, reason)
        create(:dossier, :en_construction, user: user).hide_and_keep_track!(user, reason)
      end
    end

    it do
      expect(Dossier.en_brouillon_expired_to_delete.count).to eq(2)
      expect(Dossier.en_construction_expired_to_delete.count).to eq(2)
    end
  end

  describe "discarded procedure dossier should be able to access it's procedure" do
    let(:dossier) { create(:dossier) }
    let(:procedure) { dossier.reload.procedure }

    before { dossier.procedure.discard! }

    it do
      expect(procedure).not_to be_nil
      expect(procedure.discarded?).to be_truthy
    end
  end

  describe "to_feature_collection" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :carte }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ_carte) { dossier.champs.first }
    let(:geo_area) { build(:geo_area, :selection_utilisateur, :polygon) }

    before do
      champ_carte.update(geo_areas: [geo_area])
    end

    it 'should have all champs carto' do
      expect(dossier.to_feature_collection).to eq({
        type: 'FeatureCollection',
        id: dossier.id,
        bbox: [2.428439855575562, 46.538491597754714, 2.42824137210846, 46.53841410755813],
        features: [
          {
            type: 'Feature',
            geometry: {
              coordinates: [[[2.428439855575562, 46.538476837725796], [2.4284291267395024, 46.53842148758162], [2.4282521009445195, 46.53841410755813], [2.42824137210846, 46.53847314771794], [2.428284287452698, 46.53847314771794], [2.428364753723145, 46.538487907747864], [2.4284291267395024, 46.538491597754714], [2.428439855575562, 46.538476837725796]]],
              type: 'Polygon',
            },
            properties: {
              area: 103.6,
              champ_label: champ_carte.libelle,
              champ_id: champ_carte.stable_id,
              champ_private: false,
              dossier_id: dossier.id,
              id: geo_area.id,
              source: 'selection_utilisateur',
            },
          },
        ],
      })
    end
  end

  describe "with_notifiable_procedure" do
    let(:test_procedure) { create(:procedure) }
    let(:published_procedure) { create(:procedure, :published) }
    let(:closed_procedure) { create(:procedure, :closed) }
    let(:unpublished_procedure) { create(:procedure, :unpublished) }

    let!(:dossier_on_test_procedure) { create(:dossier, procedure: test_procedure) }
    let!(:dossier_on_published_procedure) { create(:dossier, procedure: published_procedure) }
    let!(:dossier_on_closed_procedure) { create(:dossier, procedure: closed_procedure) }
    let!(:dossier_on_unpublished_procedure) { create(:dossier, procedure: unpublished_procedure) }

    let(:notify_on_closed) { false }
    let(:dossiers) { Dossier.with_notifiable_procedure(notify_on_closed: notify_on_closed) }

    it 'should find dossiers with notifiable procedure' do
      expect(dossiers).to match_array([dossier_on_published_procedure, dossier_on_unpublished_procedure])
    end

    context 'when notify on closed is true' do
      let(:notify_on_closed) { true }

      it 'should find dossiers with notifiable procedure' do
        expect(dossiers).to match_array([dossier_on_published_procedure, dossier_on_closed_procedure, dossier_on_unpublished_procedure])
      end
    end
  end

  describe "champ_values_for_export" do
    context 'with integer_number' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :integer_number, libelle: 'c1' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:integer_number_type_de_champ) { procedure.active_revision.types_de_champ_public.find(&:integer_number?) }

      it 'give me back my decimal number' do
        dossier
        expect {
          integer_number_type_de_champ.update(type_champ: :decimal_number)
        }.to change { dossier.reload.champ_values_for_export(procedure.all_revisions_types_de_champ.not_repetition.to_a, format: :xlsx) }
          .from([["c1", 42]]).to([["c1", 42.0]])
      end
    end
    context 'with a unconditionnal procedure' do
      let(:procedure) { create(:procedure, types_de_champ_public:, zones: [create(:zone)]) }
      let(:types_de_champ_public) do
        [
          { type: :text },
          { type: :datetime },
          { type: :yes_no },
          { type: :explication },
          { type: :communes },
          { type: :repetition, children: [{ type: :text }] },
        ]
      end

      let(:text_type_de_champ) { procedure.active_revision.types_de_champ_public.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:text) } }
      let(:yes_no_type_de_champ) { procedure.active_revision.types_de_champ_public.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:yes_no) } }
      let(:datetime_type_de_champ) { procedure.active_revision.types_de_champ_public.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:datetime) } }
      let(:explication_type_de_champ) { procedure.active_revision.types_de_champ_public.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:explication) } }
      let(:commune_type_de_champ) { procedure.active_revision.types_de_champ_public.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:communes) } }
      let(:repetition_type_de_champ) { procedure.active_revision.types_de_champ_public.find { |type_de_champ| type_de_champ.type_champ == TypeDeChamp.type_champs.fetch(:repetition) } }
      let(:repetition_champ) { dossier.project_champs_public.find(&:repetition?) }
      let(:repetition_second_revision_champ) { dossier_second_revision.project_champs_public.find(&:repetition?) }
      let(:dossier) { create(:dossier, procedure: procedure) }
      let(:dossier_second_revision) { create(:dossier, procedure: procedure) }
      let(:dossier_champ_values_for_export) { dossier.champ_values_for_export(procedure.types_de_champ_for_procedure_export, format: :xlsx) }
      let(:dossier_second_revision_champ_values_for_export) { dossier_second_revision.champ_values_for_export(procedure.types_de_champ_for_procedure_export, format: :xlsx) }

      context "when procedure published" do
        before do
          procedure.publish!(procedure.administrateurs.first)
          dossier
          procedure.draft_revision.remove_type_de_champ(text_type_de_champ.stable_id)
          coordinate = procedure.draft_revision.add_type_de_champ(type_champ: TypeDeChamp.type_champs.fetch(:text), libelle: 'New text field', after_stable_id: repetition_type_de_champ.stable_id)
          procedure.draft_revision.find_and_ensure_exclusive_use(yes_no_type_de_champ.stable_id).update(libelle: 'Updated yes/no')
          procedure.draft_revision.find_and_ensure_exclusive_use(commune_type_de_champ.stable_id).update(libelle: 'Commune de naissance')
          procedure.draft_revision.find_and_ensure_exclusive_use(repetition_type_de_champ.stable_id).update(libelle: 'Repetition')
          procedure.publish_revision!(procedure.administrateurs.first)
          dossier.reload
          procedure.reload
        end

        it "should have champs from all revisions" do
          expect(dossier.types_de_champ_public.map(&:libelle)).to eq([text_type_de_champ.libelle, datetime_type_de_champ.libelle, "Yes/no", explication_type_de_champ.libelle, commune_type_de_champ.libelle, repetition_type_de_champ.libelle])
          expect(dossier_second_revision.types_de_champ_public.map(&:libelle)).to eq([datetime_type_de_champ.libelle, "Updated yes/no", explication_type_de_champ.libelle, 'Commune de naissance', "Repetition", "New text field"])
          expect(dossier_champ_values_for_export.map { |(libelle)| libelle }).to eq([datetime_type_de_champ.libelle, text_type_de_champ.libelle, "Updated yes/no", "Commune de naissance", "Commune de naissance (Code INSEE)", "Commune de naissance (Département)", "New text field"])
          expect(dossier_champ_values_for_export).to eq(dossier_second_revision_champ_values_for_export)
        end

        context 'within a repetition having a type de champs commune (multiple values for export)' do
          it 'works' do
            proc_test = create(:procedure)

            draft = proc_test.draft_revision

            tdc_repetition = draft.add_type_de_champ(type_champ: :repetition, libelle: "repetition")
            draft.add_type_de_champ(type_champ: :communes, libelle: "communes", parent_stable_id: tdc_repetition.stable_id)

            dossier_test = create(:dossier, procedure: proc_test)
            type_champs = proc_test.all_revisions_types_de_champ(parent: tdc_repetition).to_a
            expect(type_champs.size).to eq(1)
            expect(dossier.champ_values_for_export(type_champs, format: :xlsx).size).to eq(3)
          end
        end

        context 'for dossier having a champ not in his revision' do
          let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
          let(:dossier_second_revision) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

          it 'should see champ' do
            expect do
              dossier.rebase!
              dossier.reload
            end.not_to change { dossier.champ_values_for_export(procedure.types_de_champ_for_procedure_export, format: :xlsx) }
          end
        end
      end

      context "when procedure brouillon" do
        let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }, { type: :explication }]) }

        it "should not contain non-exportable types de champ" do
          expect(dossier_champ_values_for_export.map { |(libelle)| libelle }).to eq([text_type_de_champ.libelle])
        end
      end
    end

    context 'with a procedure with a condition' do
      include Logic
      let(:types_de_champ) { [{ type: :yes_no }, { type: :text }] }
      let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:yes_no_tdc) { procedure.active_revision.types_de_champ_public.first }
      let(:text_tdc) { procedure.active_revision.types_de_champ_public.second }
      let(:tdcs) { dossier.project_champs_public.map(&:type_de_champ) }

      subject { dossier.champ_values_for_export(tdcs, format: :xlsx) }

      before do
        text_tdc.update(condition: ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))

        yes_no, text = dossier.project_champs_public
        yes_no.update(value: yes_no_value)
        text.update(value: 'text')
      end

      context 'with a champ visible' do
        let(:yes_no_value) { 'true' }

        it { is_expected.to eq([[yes_no_tdc.libelle, "Oui"], [text_tdc.libelle, "text"]]) }
      end

      context 'with a champ invisible' do
        let(:yes_no_value) { 'false' }

        it { is_expected.to eq([[yes_no_tdc.libelle, "Non"], [text_tdc.libelle, nil]]) }
      end

      context 'with another revision' do
        let(:tdc_from_another_revision) { create(:type_de_champ_communes, libelle: 'commune', condition: ds_eq(constant(true), constant(true))) }
        let(:tdcs) { dossier.project_champs_public.map(&:type_de_champ) << tdc_from_another_revision }
        let(:yes_no_value) { 'true' }

        let(:expected) do
          [
            [yes_no_tdc.libelle, "Oui"],
            [text_tdc.libelle, "text"],
            ["commune", nil],
            ["commune (Code INSEE)", nil],
            ["commune (Département)", nil],
          ]
        end

        it { is_expected.to eq(expected) }
      end
    end
  end

  describe '#log_api_entreprise_job_exception' do
    let(:dossier) { create(:dossier) }

    context "add execption to the log" do
      before do
        dossier.log_api_entreprise_job_exception(StandardError.new('My special exception!'))
      end

      it { expect(dossier.api_entreprise_job_exceptions).to eq(['#<StandardError: My special exception!>']) }
    end
  end

  describe "#destroy" do
    let(:procedure) { create(:procedure, :with_all_champs, :with_all_annotations) }
    let(:transfer) { create(:dossier_transfer) }
    let(:dossier) { create(:dossier, :with_populated_champs, :with_populated_annotations, transfer: transfer, procedure: procedure) }

    before do
      create(:dossier, transfer: transfer)
      create(:attestation, dossier: dossier)
    end

    it "can destroy dossier, reset demarche, logg context", :slow do
      json_message = nil
      allow(Rails.logger).to receive(:info) { json_message ||= _1 }

      expect(dossier.destroy).to be_truthy
      expect { dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)

      expect(JSON.parse(json_message)).to a_hash_including(
        { message: "Dossier destroyed #{dossier.id}", dossier_id: dossier.id, procedure_id: procedure.id }.stringify_keys
      )

      expect { dossier.procedure.reset! }.not_to raise_error
      expect { dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#spreadsheet_columns" do
    let(:dossier) { create(:dossier) }

    context 'user france connected' do
      let(:dossier) { build(:dossier, user: build(:user, france_connect_informations: [build(:france_connect_information)])) }
      it { expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(["FranceConnect ?", true]) }
    end

    context 'user not france connected' do
      let(:dossier) { build(:dossier) }
      it { expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(["FranceConnect ?", false]) }
    end

    context 'for_individual' do
      let(:dossier) { create(:dossier, procedure: create(:procedure, :for_individual)) }
      it do
        expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(["Dépôt pour un tiers", :for_tiers])
        expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(['Nom du mandataire', :mandataire_last_name])
        expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(['Prénom du mandataire', :mandataire_first_name])
      end
    end

    it { expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(["État du dossier", "Brouillon"]) }

    context 'procedure sva' do
      let(:dossier) { build(:dossier, :en_instruction, procedure: create(:procedure, :sva)) }

      it { expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(["Date décision SVA", :sva_svr_decision_on]) }
    end

    context 'procedure svr' do
      let(:dossier) { build(:dossier, :en_instruction, procedure: create(:procedure, :svr)) }

      it { expect(dossier.spreadsheet_columns(types_de_champ: [])).to include(["Date décision SVR", :sva_svr_decision_on]) }
    end
  end

  describe '#processed_in_month' do
    let(:dossier_accepte_at) { DateTime.new(2022, 3, 31, 12, 0) }
    before do
      travel_to(dossier_accepte_at) do
        dossier = create(:dossier, :accepte)
      end
    end

    context 'given a date' do
      let(:archive_date) { Date.new(2022, 3, 1) }
      it 'includes a dossier processed_at at last day of month' do
        expect(Dossier.processed_in_month(archive_date).count).to eq(1)
      end
    end

    context 'given a datetime' do
      let(:archive_date) { DateTime.new(2022, 3, 1, 12, 0) }
      it 'includes a dossier processed_at at last day of month' do
        expect(Dossier.processed_in_month(archive_date).count).to eq(1)
      end
    end
  end

  describe '#processed_by_month' do
    let(:procedure) { create(:procedure, :published, groupe_instructeurs: [groupe_instructeurs]) }
    let(:groupe_instructeurs) { create(:groupe_instructeur) }

    before do
      create_dossier_for_month(procedure, 2021, 3)
      create_dossier_for_month(procedure, 2021, 3)
      create_archived_dossier_for_month(procedure, 2021, 3)
      create_dossier_for_month(procedure, 2021, 2)
    end

    subject do
      travel_to(Time.zone.local(2021, 3, 5)) do
        Dossier.processed_by_month(groupe_instructeurs).count
      end
    end

    it 'count dossiers_termines by month' do
      expect(count_for_month(subject, 3)).to eq 3
      expect(count_for_month(subject, 2)).to eq 1
    end

    it 'returns descending order by month' do
      expect(subject.keys.first.month).to eq 3
      expect(subject.keys.last.month).to eq 2
    end
  end

  describe 'BatchOperation' do
    subject { build(:dossier) }
    it { is_expected.to belong_to(:batch_operation).optional }
  end

  describe '#orphan?' do
    subject(:orphan) { dossier.orphan? }

    context 'when the dossier is prefilled' do
      context 'when the dossier has a user' do
        let(:dossier) { build(:dossier, :prefilled) }

        it { expect(orphan).to be_falsey }
      end

      context 'when the dossier does not have a user' do
        let(:dossier) { build(:dossier, :prefilled, user: nil) }

        it { expect(orphan).to be_truthy }
      end
    end

    context 'when the dossier is not prefilled' do
      context 'when the dossier has a user' do
        let(:dossier) { build(:dossier) }

        it { expect(orphan).to be_falsey }
      end

      context 'when the dossier does not have a user' do
        let(:dossier) { build(:dossier, user: nil) }

        it { expect(orphan).to be_falsey }
      end
    end
  end

  describe '#owned_by?' do
    subject(:owned_by) { dossier.owned_by?(user) }

    context 'when the dossier is orphan' do
      let(:dossier) { build(:dossier, user: nil) }
      let(:user) { build(:user) }

      it { expect(owned_by).to be_falsey }
    end

    context 'when the given user is nil' do
      let(:dossier) { build(:dossier) }
      let(:user) { nil }

      it { expect(owned_by).to be_falsey }
    end

    context 'when the dossier has a user and it is not the given user' do
      let(:dossier) { build(:dossier) }
      let(:user) { build(:user) }

      it { expect(owned_by).to be_falsey }
    end

    context 'when the dossier has a user and it is the given user' do
      let(:dossier) { build(:dossier, user: user) }
      let(:user) { build(:user) }

      it { expect(owned_by).to be_truthy }
    end
  end

  describe 'update procedure dossiers count' do
    let(:dossier) { create(:dossier, :brouillon, :with_individual) }

    it 'update procedure dossiers count when passing to construction' do
      expect(dossier.procedure).to receive(:compute_dossiers_count)
      dossier.passer_en_construction!
    end
  end

  describe '#sva_svr_decision_in_days' do
    let(:dossier) { create(:dossier, :en_instruction, sva_svr_decision_on: 10.days.from_now) }

    it { expect(dossier.sva_svr_decision_in_days).to eq 10 }
  end

  describe '#update_champs_timestamps' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{}, { type: :piece_justificative }, { type: :titre_identite }]) }
    let(:dossier) { create(:dossier, procedure:, brouillon_close_to_expiration_notice_sent_at: 10.days.ago) }
    let(:changed_champs) { dossier.champs.filter(&:text?) }

    subject { -> { dossier.update_champs_timestamps(changed_champs, Champ::USER_BUFFER_STREAM) } }

    it do
      is_expected.to change(dossier, :last_champ_updated_at)
      is_expected.to change(dossier, :updated_at)
    end

    context 'when there is piece justificative' do
      let(:changed_champs) { dossier.champs.filter(&:piece_justificative?) }

      it do
        is_expected.to change(dossier, :last_champ_updated_at)
        is_expected.to change(dossier, :updated_at)
      end
    end

    context 'when there is titre identite' do
      let(:changed_champs) { dossier.champs.filter(&:titre_identite?) }

      it do
        is_expected.to change(dossier, :last_champ_updated_at)
        is_expected.to change(dossier, :updated_at)
      end
    end
  end

  describe '#never_touched_brouillon_expired' do
    let!(:dossier) { travel_to(3.weeks.ago) { create(:dossier, :brouillon, last_champ_updated_at: nil) } }
    let!(:dossier_2) { travel_to(1.week.ago) { create(:dossier, :brouillon, last_champ_updated_at: nil) } }
    let!(:dossier_with_champ_updated) { travel_to(3.weeks.ago) { create(:dossier, :brouillon, last_champ_updated_at: 1.day.ago) } }

    let!(:dossier_en_construction) { create(:dossier, :en_construction, last_champ_updated_at: nil) }

    subject { Dossier.never_touched_brouillon_expired }

    it { is_expected.to contain_exactly(dossier) }

    context 'when the dossier has been cloned' do
      let!(:cloned_dossier) { travel_to(3.weeks.ago) { dossier.clone } }
      let!(:cloned_dossier_2) { travel_to(3.weeks.ago) { dossier_with_champ_updated.clone } }

      it { is_expected.to contain_exactly(dossier) }
    end

    context 'when the dossier has an etablissement' do
      let!(:dossier_with_etablissement) { travel_to(3.weeks.ago) { create(:dossier, :brouillon, last_champ_updated_at: nil, etablissement: create(:etablissement)) } }

      it { is_expected.not_to include(dossier_with_etablissement) }
    end

    context 'when the dossier has an individual' do
      let!(:dossier_with_individual) { travel_to(3.weeks.ago) { create(:dossier, :brouillon, last_champ_updated_at: nil, individual: create(:individual)) } }

      it { is_expected.not_to include(dossier_with_individual) }
    end
  end

  private

  def count_for_month(processed_by_month, month)
    processed_by_month.find { |date, _count| date.month == month }[1]
  end

  def create_dossier_for_month(procedure, year, month)
    travel_to(Time.zone.local(year, month, 5)) do
      create(:dossier, :accepte, :with_attestation_acceptation, procedure: procedure)
    end
  end

  def create_archived_dossier_for_month(procedure, year, month)
    travel_to(Time.zone.local(year, month, 5)) do
      create(:dossier, :accepte, :archived, :with_attestation_acceptation, procedure: procedure)
    end
  end
end
