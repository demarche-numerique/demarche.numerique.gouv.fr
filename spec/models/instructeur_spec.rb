# frozen_string_literal: true

describe Instructeur, type: :model do
  let_it_be(:admin) { create :administrateur }
  let_it_be(:procedure) { create :procedure, :published, administrateur: admin }
  let_it_be(:procedure_2) { create :procedure, :published, administrateur: admin }
  let_it_be(:procedure_3) { create :procedure, :published, administrateur: admin }
  let_it_be(:instructeur, reload: true) { create :instructeur, administrateurs: [admin] }
  let_it_be(:procedure_assign) { assign(procedure) }

  before_all do
    assign(procedure_2)
  end

  describe 'associations' do
    it do
      is_expected.to have_many(:archives)
      is_expected.to have_many(:exports)
      is_expected.to have_and_belong_to_many(:administrateurs)
      is_expected.to have_many(:batch_operations)
    end
  end

  describe 'follow' do
    let(:dossier) { create :dossier }
    let(:already_followed_dossier) { create :dossier }

    before { instructeur.followed_dossiers << already_followed_dossier }

    context 'when a instructeur follow a dossier for the first time' do
      before { instructeur.follow(dossier) }

      it { expect(instructeur.follow?(dossier)).to be true }
    end

    context 'when a instructeur follows a dossier already followed' do
      before { instructeur.follow(already_followed_dossier) }

      it { expect(instructeur.follow?(already_followed_dossier)).to be true }
    end

    context "when a instructeur is the first to follow a dossier" do
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_depose) }

      before { instructeur.follow(dossier) }

      it "destroy dossier_depose notification" do
        expect(DossierNotification.exists?(notification.id)).to be_falsey
      end
    end

    context "when a instructeur follow a dossier that has had notifications" do
      let!(:dossier_with_notifications) { create(:dossier, :en_construction, last_champ_updated_at: Time.zone.now, depose_at: Time.zone.yesterday, last_champ_private_updated_at: Time.zone.now) }
      let!(:commentaire) { create(:commentaire, dossier: dossier_with_notifications) }
      let!(:avis_with_answer) { create(:avis, :with_answer, dossier: dossier_with_notifications) }
      let!(:avis_without_answer) { create(:avis, dossier: dossier_with_notifications) }
      let!(:commentaire_correction) { create(:commentaire, dossier: dossier_with_notifications, instructeur:) }
      let!(:correction) { create(:dossier_correction, dossier: dossier_with_notifications, commentaire: commentaire_correction) }

      subject { instructeur.follow(dossier_with_notifications) }

      it "creates all previous notifications for the instructeur" do
        subject

        expect(DossierNotification.count).to eq(6)
        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier_with_notifications, notification_type: :annotation_instructeur)
        ).to be_truthy
        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier_with_notifications, notification_type: :message)
        ).to be_truthy
        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier_with_notifications, notification_type: :dossier_modifie)
        ).to be_truthy
        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier_with_notifications, notification_type: :avis_externe)
        ).to be_truthy
        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier_with_notifications, notification_type: :attente_avis)
        ).to be_truthy
        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier_with_notifications, notification_type: :attente_correction)
        ).to be_truthy
      end

      context "when there are only commentaires from the instructeur who starts to follow" do
        before do
          commentaire.update!(instructeur:)
        end

        it "does not create message notification" do
          subject

          expect(DossierNotification.count).to eq(5)

          expect(DossierNotification.pluck(:notification_type)).not_to include('message')
        end
      end
    end
  end

  describe '#unfollow' do
    let(:already_followed_dossier) { create(:dossier, procedure:) }
    before { instructeur.followed_dossiers << already_followed_dossier }

    context 'when a instructeur unfollow a dossier already followed' do
      before do
        instructeur.unfollow(already_followed_dossier)
        already_followed_dossier.reload
      end

      it do
        expect(instructeur.follow?(already_followed_dossier)).to be false
        expect(instructeur.previously_followed_dossiers).to include(already_followed_dossier)
      end
    end

    context "when the instructeur has notifications on the dossier" do
      let!(:notification_with_followed_preference) { create(:dossier_notification, dossier: already_followed_dossier, instructeur:, notification_type: :dossier_modifie) }
      let!(:notification_with_all_preference) { create(:dossier_notification, dossier: already_followed_dossier, instructeur:, notification_type: :message) }
      let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, display_dossier_modifie_notifications: 'followed', display_message_notifications: 'all') }

      it "destroys only notifications for which the instructeur has an 'followed' preference" do
        instructeur.unfollow(already_followed_dossier)

        expect(DossierNotification.exists?(notification_with_followed_preference.id)).to be_falsey
        expect(DossierNotification.exists?(notification_with_all_preference.id)).to be_truthy
      end
    end
  end

  describe '#follow?' do
    let!(:dossier) { create :dossier, procedure: procedure }

    subject { instructeur.follow?(dossier) }

    context 'when instructeur follow a dossier' do
      before do
        create :follow, dossier_id: dossier.id, instructeur_id: instructeur.id
      end

      it { is_expected.to be_truthy }
    end

    context 'when instructeur not follow a dossier' do
      it { is_expected.to be_falsey }
    end
  end

  describe "#assign_to_procedure" do
    subject { instructeur.assign_to_procedure(procedure_to_assign) }

    context "with a procedure not already assigned" do
      let(:procedure_to_assign) { procedure_3 }

      it { is_expected.to be_truthy }
      it { expect { subject }.to change(instructeur.procedures, :count) }
      it do
        subject
        expect(instructeur.groupe_instructeurs).to include(procedure_to_assign.defaut_groupe_instructeur)
      end
    end

    context "with an already assigned procedure" do
      let(:procedure_to_assign) { procedure }

      it { is_expected.to be_falsey }
      it { expect { subject }.not_to change(instructeur.procedures, :count) }
    end
  end

  describe 'weekly_email_summary_data' do
    subject { instructeur2.weekly_email_summary_data }

    let(:instructeur2) { create(:instructeur) }
    let!(:groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur2]) }
    let!(:instructeur2_procedure) { create(:instructeurs_procedure, instructeur: instructeur2, procedure:) }
    let(:monday) { Time.zone.local(2025, 12, 1) }

    before { travel_to(monday) }

    context 'when a procedure published was active' do
      let(:procedure) { create(:procedure, :published, libelle: 'procedure') }
      let!(:dossier) { create(:dossier, :en_instruction, procedure:, en_instruction_at: 1.day.ago, groupe_instructeur:) }

      context 'when the instructeur has not weekly summary email' do
        it { is_expected.to eq(nil) }
      end

      context 'when the instructeur has weekly summary email' do
        before { instructeur2_procedure.update!(weekly_email_summary: true) }

        it { is_expected.not_to eq(nil) }
      end
    end

    context 'when a procedure not published was active with email' do
      let!(:procedure) { create(:procedure, libelle: 'procedure') }
      let!(:dossier) { create(:dossier, :en_instruction, procedure:, en_instruction_at: 1.day.ago, groupe_instructeur:) }

      before { instructeur2_procedure.update!(weekly_email_summary: true) }

      it { is_expected.to eq(nil) }
    end

    context 'when a procedure published was not active with email' do
      let!(:procedure) { create(:procedure, :published, libelle: 'procedure') }

      before { instructeur2_procedure.update!(weekly_email_summary: true) }

      context "when there is a dossier in brouillon" do
        let!(:dossier) { create(:dossier, :brouillon, procedure:, created_at: 1.day.ago, groupe_instructeur:) }

        it { is_expected.to eq(nil) }
      end
    end

    context "when a procedure routee was active with email" do
      let(:procedure) { create(:procedure, :published, libelle: 'procedure') }
      let!(:other_groupe_instructeur) { create(:groupe_instructeur, procedure:) }

      before { instructeur2_procedure.update!(weekly_email_summary: true) }

      context "when activites are in groupe instructeur" do
        let!(:dossier) { create(:dossier, :en_instruction, procedure:, en_instruction_at: 1.day.ago, groupe_instructeur:) }

        it { is_expected.not_to eq(nil) }
      end

      context "when activites are in other groupe instructeur" do
        let!(:dossier) { create(:dossier, :en_instruction, procedure:, en_instruction_at: 1.day.ago, groupe_instructeur: other_groupe_instructeur) }

        it { is_expected.to eq(nil) }
      end
    end
  end

  describe "procedure_presentation_and_errors_for_procedure_id" do
    let(:procedure_presentation_and_errors) { instructeur.procedure_presentation_and_errors_for_procedure_id(procedure_id) }
    let(:procedure_presentation) { procedure_presentation_and_errors.first }
    let(:errors) { procedure_presentation_and_errors.second }

    context 'with explicit presentation' do
      let(:procedure_id) { procedure.id }
      let!(:pp) { ProcedurePresentation.create(assign_to: procedure_assign) }

      it do
        expect(procedure_presentation).to eq(pp)
        expect(errors).to be_nil
      end
    end

    context 'with default presentation' do
      let(:procedure_id) { procedure_2.id }

      it do
        expect(procedure_presentation).to be_persisted
        expect(errors).to be_nil
      end
    end
  end

  describe '#mark_tab_as_seen' do
    let!(:dossier) { create(:dossier, :en_construction, :followed) }
    let(:instructeur) { dossier.follows.first.instructeur }
    let(:freeze_date) { Time.zone.parse('12/12/2012') }

    context 'when demande is acknowledged' do
      let(:follow) { instructeur.follows.find_by(dossier: dossier) }

      before do
        travel_to(freeze_date)
        instructeur.mark_tab_as_seen(dossier, :demande)
      end

      it { expect(follow.demande_seen_at).to eq(freeze_date) }
    end
  end

  describe '#young_login_token?' do
    let!(:instructeur) { create(:instructeur) }

    context 'when there is a token' do
      let!(:good_token) { instructeur.create_trusted_device_token }

      context 'when the token has just been created' do
        it { expect(instructeur.young_login_token?).to be true }
      end

      context 'when the token is a bit old' do
        before { instructeur.trusted_device_tokens.first.update(created_at: (TrustedDeviceToken::LOGIN_TOKEN_YOUTH + 1.minute).ago) }
        it { expect(instructeur.young_login_token?).to be false }
      end
    end

    context 'when there are no token' do
      it { expect(instructeur.young_login_token?).to be_falsey }
    end
  end

  describe '#daily_email_summary_data' do
    let_it_be(:instructeur) { create(:instructeur) }
    let!(:groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }
    let(:procedure) { create(:procedure, :published) }
    let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, daily_email_summary: true) }

    context 'when a dossier in construction exists' do
      let!(:dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur:) }

      it do
        expect(instructeur.daily_email_summary_data).to eq([
          {
            nb_en_construction: 1,
            nb_en_instruction: 0,
            nb_processed: 0,
            nb_accepted: 0,
            nb_refused: 0,
            nb_closed_without_continuation: 0,
            nb_dossiers_with_notifications: 0,
            nb_notifications: {},
            procedure_id: procedure.id,
            procedure_libelle: procedure.libelle,
          },
        ])
      end
    end

    context 'when a notification exists' do
      let(:dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur:) }
      let!(:notification_to_count) { create(:dossier_notification, instructeur:, dossier:, notification_type: :dossier_modifie) }
      let!(:notification_not_count) { create(:dossier_notification, instructeur:, dossier:) }

      it do
        expect(instructeur.daily_email_summary_data).to eq([
          {
            nb_en_construction: 1,
            nb_en_instruction: 0,
            nb_processed: 0,
            nb_accepted: 0,
            nb_refused: 0,
            nb_closed_without_continuation: 0,
            nb_dossiers_with_notifications: 1,
            nb_notifications: { 'dossier_modifie' => 1 },
            procedure_id: procedure.id,
            procedure_libelle: procedure.libelle,
          },
        ])
      end
    end

    context 'when a dossier in instruction exists' do
      let!(:dossier) { create(:dossier, :en_instruction, procedure:, groupe_instructeur:) }

      it do
        expect(instructeur.daily_email_summary_data).to eq([
          {
            nb_en_construction: 0,
            nb_en_instruction: 1,
            nb_processed: 0,
            nb_accepted: 0,
            nb_refused: 0,
            nb_closed_without_continuation: 0,
            nb_dossiers_with_notifications: 0,
            nb_notifications: {},
            procedure_id: procedure.id,
            procedure_libelle: procedure.libelle,
          },
        ])
      end
    end

    context 'when a dossier accepte, refuse and sans suite exists' do
      let!(:dossier_accepte) { create(:dossier, :accepte, procedure:, groupe_instructeur:) }
      let!(:dossier_refuse) { create(:dossier, :refuse, procedure:, groupe_instructeur:) }
      let!(:dossier_sans_suite) { create(:dossier, :sans_suite, procedure:, groupe_instructeur:) }

      it do
        expect(instructeur.daily_email_summary_data).to eq([
          {
            nb_en_construction: 0,
            nb_en_instruction: 0,
            nb_processed: 3,
            nb_accepted: 1,
            nb_refused: 1,
            nb_closed_without_continuation: 1,
            nb_dossiers_with_notifications: 0,
            nb_notifications: {},
            procedure_id: procedure.id,
            procedure_libelle: procedure.libelle,
          },
        ])
      end
    end

    context 'otherwise' do
      it { expect(instructeur.daily_email_summary_data).to eq([]) }
    end
  end

  describe '#procedures' do
    let(:procedure_a) { create(:procedure) }
    let(:instructeur_a) { create(:instructeur, groupe_instructeurs: [procedure_a.defaut_groupe_instructeur]) }

    before do
      gi2 = procedure_a.groupe_instructeurs.create(label: 'gi2')

      instructeur_a.groupe_instructeurs << gi2
    end

    it { expect(instructeur_a.procedures.all.to_ary).to eq([procedure_a]) }
  end

  describe "#can_be_deleted?" do
    subject { instructeur.can_be_deleted? }

    context 'when the instructeur is an administrateur' do
      let!(:administrateur) { administrateurs(:default_admin) }
      let(:instructeur) { administrateur.instructeur }

      it { is_expected.to be false }
    end

    context "when the instructeur's procedures have other instructeurs" do
      let(:instructeur_not_admin) { create(:instructeur) }
      let(:autre_instructeur) { create(:instructeur) }

      it "can be deleted" do
        assign(procedure, instructeur_assigne: instructeur_not_admin)
        assign(procedure, instructeur_assigne: autre_instructeur)
        expect(autre_instructeur.can_be_deleted?).to be_truthy
      end
    end

    context "when the instructeur's procedures is the only one" do
      let(:instructeur_not_admin) { create :instructeur }
      let(:autre_procedure) { create :procedure }
      it "can be deleted" do
        assign(autre_procedure, instructeur_assigne: instructeur_not_admin)
        expect(instructeur_not_admin.can_be_deleted?).to be_falsy
      end
    end
  end

  describe "#dossiers_count_summary" do
    let_it_be(:instructeur_2, reload: true) { create(:instructeur) }
    let_it_be(:instructeur_3) { create(:instructeur) }
    let_it_be(:procedure, reload: true) { create(:procedure, instructeurs: [instructeur_2, instructeur_3], procedure_expires_when_termine_enabled: true) }
    let_it_be(:gi_1) { procedure.defaut_groupe_instructeur }
    let_it_be(:gi_2) { create(:groupe_instructeur, label: '2', procedure: procedure) }
    let_it_be(:gi_3) { create(:groupe_instructeur, label: '3', procedure: procedure) }

    subject do
      instructeur_2.dossiers_count_summary([gi_1.id, gi_2.id])
    end

    context "when logged in, and belonging to gi_1, gi_2" do
      before do
        instructeur.groupe_instructeurs << gi_2
      end

      context "without any dossier" do
        it do
          expect(subject['a_suivre']).to eq(0)
          expect(subject['suivis']).to eq(0)
          expect(subject['traites']).to eq(0)
          expect(subject['tous']).to eq(0)
          expect(subject['archives']).to eq(0)
          expect(subject['expirant']).to eq(0)
        end
      end

      context 'with a new brouillon dossier' do
        let!(:brouillon_dossier) { create(:dossier, procedure: procedure) }

        it do
          expect(subject['a_suivre']).to eq(0)
          expect(subject['suivis']).to eq(0)
          expect(subject['traites']).to eq(0)
          expect(subject['tous']).to eq(0)
          expect(subject['archives']).to eq(0)
          expect(subject['expirant']).to eq(0)
        end
      end

      context 'with a new dossier without follower' do
        let!(:new_unfollow_dossier) { create(:dossier, :en_instruction, procedure: procedure) }

        it do
          expect(subject['a_suivre']).to eq(1)
          expect(subject['suivis']).to eq(0)
          expect(subject['traites']).to eq(0)
          expect(subject['tous']).to eq(1)
          expect(subject['archives']).to eq(0)
          expect(subject['expirant']).to eq(0)
        end

        context 'and dossiers without follower on each of the others groups' do
          let!(:new_unfollow_dossier_on_gi_2) { create(:dossier, :en_instruction, groupe_instructeur: gi_2) }
          let!(:new_unfollow_dossier_on_gi_3) { create(:dossier, :en_instruction, groupe_instructeur: gi_3) }

          before { subject }

          it do
            expect(subject['a_suivre']).to eq(2)
            expect(subject['tous']).to eq(2)
          end
        end
      end

      context 'with a new dossier with a follower' do
        let!(:new_followed_dossier) { create(:dossier, :en_instruction, procedure: procedure) }

        before do
          instructeur_2.followed_dossiers << new_followed_dossier
        end

        it do
          expect(subject['a_suivre']).to eq(0)
          expect(subject['suivis']).to eq(1)
          expect(subject['traites']).to eq(0)
          expect(subject['tous']).to eq(1)
          expect(subject['archives']).to eq(0)
          expect(subject['expirant']).to eq(0)
        end

        context 'and another one follows the same dossier' do
          before do
            instructeur_3.followed_dossiers << new_followed_dossier
          end

          it do
            expect(subject['a_suivre']).to eq(0)
            expect(subject['suivis']).to eq(1)
            expect(subject['traites']).to eq(0)
            expect(subject['tous']).to eq(1)
            expect(subject['archives']).to eq(0)
            expect(subject['expirant']).to eq(0)
          end
        end

        context 'and dossier with a follower on each of the others groups' do
          let!(:new_follow_dossier_on_gi_2) { create(:dossier, :en_instruction, groupe_instructeur: gi_2) }
          let!(:new_follow_dossier_on_gi_3) { create(:dossier, :en_instruction, groupe_instructeur: gi_3) }

          before do
            instructeur_2.followed_dossiers << new_follow_dossier_on_gi_2 << new_follow_dossier_on_gi_3
          end

          # followed dossiers on another groupe should not be displayed
          it do
            expect(subject['suivis']).to eq(2)
            expect(subject['tous']).to eq(2)
          end
        end

        context 'and dossier with a follower is unfollowed' do
          before do
            instructeur_2.unfollow(new_followed_dossier)
          end

          it do
            expect(subject['a_suivre']).to eq(1)
            expect(subject['suivis']).to eq(0)
            expect(subject['tous']).to eq(1)
            expect(subject['expirant']).to eq(0)
          end
        end
      end

      context 'with a termine dossier' do
        let!(:termine_dossier) { create(:dossier, :accepte, procedure: procedure) }

        it do
          expect(subject['a_suivre']).to eq(0)
          expect(subject['suivis']).to eq(0)
          expect(subject['traites']).to eq(1)
          expect(subject['tous']).to eq(1)
          expect(subject['archives']).to eq(0)
          expect(subject['expirant']).to eq(0)
        end

        context 'and terminer dossiers on each of the others groups' do
          let!(:termine_dossier_on_gi_2) { create(:dossier, :accepte, groupe_instructeur: gi_2) }
          let!(:termine_dossier_on_gi_3) { create(:dossier, :accepte, groupe_instructeur: gi_3) }

          before { subject }

          it do
            expect(subject['a_suivre']).to eq(0)
            expect(subject['suivis']).to eq(0)
            expect(subject['traites']).to eq(2)
            expect(subject['tous']).to eq(2)
            expect(subject['archives']).to eq(0)
            expect(subject['expirant']).to eq(0)
          end
        end
      end

      context 'with an archives dossier' do
        let!(:archives_dossier) { create(:dossier, :en_instruction, procedure: procedure, archived: true) }

        it do
          expect(subject['a_suivre']).to eq(0)
          expect(subject['suivis']).to eq(0)
          expect(subject['traites']).to eq(0)
          expect(subject['tous']).to eq(0)
          expect(subject['archives']).to eq(1)
          expect(subject['supprimes']).to eq(0)
          expect(subject['expirant']).to eq(0)
        end

        context 'and terminer dossiers on each of the others groups' do
          let!(:archives_dossier_on_gi_2) { create(:dossier, :en_instruction, groupe_instructeur: gi_2, archived: true) }
          let!(:archives_dossier_on_gi_3) { create(:dossier, :en_instruction, groupe_instructeur: gi_3, archived: true) }

          it { expect(subject['archives']).to eq(2) }
        end
      end

      context 'with an expirants dossier' do
        let!(:expiring_dossier_termine_deleted) { create(:dossier, :accepte, procedure: procedure, processed_at: 175.days.ago, hidden_by_administration_at: 2.days.ago) }
        let!(:expiring_dossier_termine_auto_deleted) { create(:dossier, :accepte, procedure: procedure, processed_at: 175.days.ago, hidden_by_expired_at: 2.days.ago) }
        let!(:expiring_dossier_termine) { create(:dossier, :accepte, procedure: procedure, processed_at: 175.days.ago) }
        let!(:expiring_dossier_en_construction) { create(:dossier, :en_construction, en_construction_at: 175.days.ago, procedure: procedure) }

        before { procedure.dossiers.each(&:update_expired_at) }

        it do
          expect(subject['a_suivre']).to eq(1)
          expect(subject['suivis']).to eq(0)
          expect(subject['traites']).to eq(1)
          expect(subject['tous']).to eq(2)
          expect(subject['archives']).to eq(0)
          expect(subject['supprimes']).to eq(2)
          expect(subject['expirant']).to eq(2)
        end
      end
    end
  end

  describe '#merge' do
    let_it_be(:old_instructeur, reload: true) { create(:instructeur) }
    let_it_be(:new_instructeur, reload: true) { create(:instructeur) }

    subject { new_instructeur.merge(old_instructeur) }

    context 'when the old instructeur does not exist' do
      let(:old_instructeur) { nil }

      it { expect { subject }.not_to raise_error }
    end

    context 'when an procedure is assigned to the old instructeur' do
      let(:procedure) { create(:procedure) }

      before do
        procedure.defaut_groupe_instructeur.instructeurs << old_instructeur
        subject
      end

      it 'transfers the assignment' do
        expect(new_instructeur.procedures).to match_array(procedure)
      end
    end

    context 'when both instructeurs are assigned to the same procedure' do
      let(:procedure) { create(:procedure) }

      before do
        procedure.defaut_groupe_instructeur.instructeurs << old_instructeur
        procedure.defaut_groupe_instructeur.instructeurs << new_instructeur
        subject
      end

      it 'keeps the assignment' do
        expect(new_instructeur.procedures).to match_array(procedure)
      end
    end

    context 'when a dossier is followed by an old instructeur' do
      let(:dossier) { create(:dossier) }

      before do
        old_instructeur.followed_dossiers << dossier
        subject
      end

      it 'transfers the dossier' do
        expect(new_instructeur.followed_dossiers).to match_array(dossier)
      end
    end

    context 'when both instructeurs follow the same dossier' do
      let(:dossier) { create(:dossier) }

      before do
        old_instructeur.followed_dossiers << dossier
        new_instructeur.followed_dossiers << dossier
        subject
      end

      it 'does not change anything' do
        expect(new_instructeur.followed_dossiers.pluck(:id)).to match_array(dossier.id)
      end
    end

    context 'when the old instructeur is on on admin list' do
      let(:administrateur) { administrateurs(:default_admin) }

      before do
        administrateur.instructeurs << old_instructeur
        subject
      end

      it 'is replaced by the new one' do
        expect(administrateur.reload.instructeurs).to match_array(new_instructeur)
      end
    end

    context 'when both are on the same admin list' do
      let(:administrateur) { administrateurs(:default_admin) }

      before do
        administrateur.instructeurs << old_instructeur
        administrateur.instructeurs << new_instructeur
        subject
      end

      it 'removes the old one' do
        expect(administrateur.reload.instructeurs).to match_array(new_instructeur)
      end
    end

    context 'when old instructeur has avis' do
      let(:avis) { create(:avis, claimant: old_instructeur) }
      before do
        avis
        subject
      end
      it 'reassign avis to new_instructeur' do
        avis.reload
        expect(avis.claimant).to eq(new_instructeur)
      end
    end
  end

  private

  def assign(procedure_to_assign, instructeur_assigne: instructeur)
    create :assign_to, instructeur: instructeur_assigne, procedure: procedure_to_assign, groupe_instructeur: procedure_to_assign.defaut_groupe_instructeur
  end
end
