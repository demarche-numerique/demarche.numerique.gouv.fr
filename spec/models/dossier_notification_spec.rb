# frozen_string_literal: true

RSpec.describe DossierNotification, type: :model do
  describe '.to_display' do
    context "when there is a display deadline" do
      let(:past_notification) { create(:dossier_notification) }
      let(:future_notification) { create(:dossier_notification, display_at: 1.day.from_now) }

      it 'includes notifications where display_at is in the past or now and excludes notifications where display_at is in the future' do
        expect(DossierNotification.to_display).to include(past_notification)
        expect(DossierNotification.to_display).not_to include(future_notification)
      end
    end

    context "when the are notifications on achived dossier" do
      let(:dossier_archived) { create(:dossier, :archived) }
      let!(:expirant_notification) { create(:dossier_notification, dossier: dossier_archived, notification_type: :dossier_expirant) }
      let!(:other_notification) { create(:dossier_notification, dossier: dossier_archived, notification_type: :message) }

      it "only displays :dossier_expirant notification" do
        expect(DossierNotification.to_display).to include(expirant_notification)
        expect(DossierNotification.to_display).not_to include(other_notification)
      end
    end

    context "when the are notifications on hidden dossier" do
      let(:dossier_expired) { create(:dossier, :hidden_by_expired) }
      let(:dossier_hidden) { create(:dossier, :hidden_by_administration) }
      let!(:suppression_notification_for_expired) { create(:dossier_notification, dossier: dossier_expired, notification_type: :dossier_suppression) }
      let!(:other_notification_for_expired) { create(:dossier_notification, dossier: dossier_expired, notification_type: :message) }
      let!(:suppression_notification_for_hidden) { create(:dossier_notification, dossier: dossier_hidden, notification_type: :dossier_suppression) }
      let!(:other_notification_for_hidden) { create(:dossier_notification, dossier: dossier_hidden, notification_type: :message) }

      it "only displays :dossier_suppression notification" do
        expect(DossierNotification.to_display).to include(suppression_notification_for_expired)
        expect(DossierNotification.to_display).not_to include(other_notification_for_expired)
        expect(DossierNotification.to_display).to include(suppression_notification_for_hidden)
        expect(DossierNotification.to_display).not_to include(other_notification_for_hidden)
      end
    end
  end

  describe 'create_notification' do
    subject { DossierNotification.create_notification(dossier, notification_type, **notification_args) }

    let(:notification_args) { {} }

    context 'dossier_depose notification' do
      let(:procedure) { create(:procedure) }
      let(:instructeur) { create(:instructeur) }
      let(:groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }
      let!(:dossier) { create(:dossier, groupe_instructeur:, depose_at: Time.zone.now, procedure:) }
      let!(:notification_type) { :dossier_depose }

      it 'create notification for all instructeurs with the correct delay to display' do
        subject
        expect(DossierNotification.count).to eq(1)

        notification = DossierNotification.first
        expect(notification.dossier).to eq(dossier)
        expect(notification.instructeur).to eq(instructeur)
        expect(notification.notification_type).to eq('dossier_depose')
        expect(notification.display_at.to_date).to eq(dossier.depose_at.to_date + DossierNotification::DELAY_DOSSIER_DEPOSE)
      end
    end

    context "message notification" do
      let_it_be(:procedure) { create(:procedure) }
      let_it_be(:instructeur) { create(:instructeur) }
      let_it_be(:other_instructeur) { create(:instructeur) }
      let_it_be(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur, other_instructeur]) }
      let_it_be(:dossier) { create(:dossier, groupe_instructeur:, procedure:) }
      let_it_be(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, display_message_notifications: 'all') }
      let_it_be(:other_instructeur_procedure) { create(:instructeurs_procedure, instructeur: other_instructeur, procedure:, display_message_notifications: 'all') }
      let(:notification_type) { :message }

      context "when user or expert send a message" do
        it "create notification for instructeurs" do
          subject

          expect(DossierNotification.count).to eq(2)

          notifications = DossierNotification.where(dossier:, notification_type: :message)

          expect(notifications.map(&:instructeur_id)).to match_array([instructeur.id, other_instructeur.id])
        end
      end

      context "when instructeur send a message" do
        let!(:notification_args) { { except_instructeur: instructeur } }

        it "create notification for instructeurs, except instructeur sender" do
          subject

          expect(DossierNotification.count).to eq(1)
          expect(DossierNotification.first.instructeur).to eq(other_instructeur)
        end
      end
    end

    context "when the instructeur has default notification preferences" do
      let_it_be(:procedure) { create(:procedure) }
      let_it_be(:instructeur, reload: true) { create(:instructeur) }
      let_it_be(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur], procedure:) }
      let_it_be(:dossier, reload: true) { create(:dossier, groupe_instructeur:) }
      let!(:notification_type) { :dossier_modifie }

      context "when the instructeur follow the dossier" do
        it 'create notification' do
          instructeur.followed_dossiers << dossier
          subject

          expect(DossierNotification.count).to eq(1)
        end
      end

      context "when the instructeur does not follow the dossier" do
        it 'does not create notification' do
          subject

          expect(DossierNotification.count).to eq(0)
        end
      end
    end

    context "when the instructeur has notification preferences" do
      let_it_be(:procedure) { create(:procedure) }
      let_it_be(:instructeur, reload: true) { create(:instructeur) }
      let_it_be(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur], procedure:) }
      let_it_be(:dossier, reload: true) { create(:dossier, groupe_instructeur:, procedure:) }
      let_it_be(:instructeur_procedure, reload: true) { create(:instructeurs_procedure, instructeur:, procedure:) }
      let!(:notification_type) { :dossier_modifie }

      context "when the instructeur never wants notifications" do
        before do
          instructeur.followed_dossiers << dossier
          instructeur_procedure.update!(display_dossier_modifie_notifications: 'none')
        end

        it 'does not create notification' do
          subject

          expect(DossierNotification.count).to eq(0)
        end
      end

      context "when the instructeur wants notifications on followed dossiers" do
        before { instructeur_procedure.update!(display_dossier_modifie_notifications: 'followed') }

        it 'does not create notification if he is not following dossier' do
          subject

          expect(DossierNotification.count).to eq(0)
        end

        it 'create notification if he is following dossier' do
          instructeur.followed_dossiers << dossier
          subject

          expect(DossierNotification.count).to eq(1)
        end
      end

      context "when the instructeur wants notifications even if he is not following the dossier" do
        before { instructeur_procedure.update!(display_dossier_modifie_notifications: 'all') }

        it 'create notification' do
          subject

          expect(DossierNotification.count).to eq(1)
        end
      end
    end
  end

  describe 'refresh_notifications_instructeur_for_followed_dossier' do
    subject { DossierNotification.refresh_notifications_instructeur_for_followed_dossier(instructeur, dossier_to_notify) }

    let_it_be(:dossier_to_notify) { create(:dossier, :en_construction, last_champ_updated_at: Time.zone.now, depose_at: Time.zone.yesterday) }
    let_it_be(:instructeur) { create(:instructeur) }

    context 'when the instructeur has default preferences for badge notification' do
      it "create notification" do
        subject

        expect(DossierNotification.count).to eq(1)

        notification = DossierNotification.first
        expect(notification.notification_type).to eq('dossier_modifie')
      end
    end

    context "when the instructeur never wants notifications" do
      let(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure_id: dossier_to_notify.procedure.id) }

      before { instructeur_procedure.update!(display_dossier_modifie_notifications: 'none') }

      it 'does not create notification' do
        expect { subject }.not_to change { DossierNotification.count }
      end
    end

    context "when the instructeur wants notifications on followed dossiers" do
      let(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure_id: dossier_to_notify.procedure.id) }

      before { instructeur_procedure.update!(display_dossier_modifie_notifications: 'followed') }

      it 'create notification' do
        subject

        expect(DossierNotification.count).to eq(1)

        notification = DossierNotification.first
        expect(notification.notification_type).to eq('dossier_modifie')
      end
    end
  end

  describe '.dossiers_to_notify' do
    subject { DossierNotification.dossiers_to_notify(Dossier.all, notification_type, instructeur.id) }

    let(:instructeur) { create(:instructeur) }

    context "when notification_type is dossier_depose" do
      let(:notification_type) { :dossier_depose }
      let!(:dossier_to_notify) { create(:dossier, state: :en_construction, follows: []) }
      let!(:dossier_not_to_notify_1) { create(:dossier, :en_construction) }
      let!(:follow) { create(:follow, instructeur:, dossier: dossier_not_to_notify_1) }
      let!(:dossier_not_to_notify_2) { create(:dossier, :accepte) }

      it "returns only dossiers en_construction without followers" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end

    context "when notification_type is dossier_expirant" do
      let(:notification_type) { :dossier_expirant }
      let!(:dossier_to_notify) { create(:dossier, :accepte) }
      let!(:dossier_to_notify_2) { create(:dossier, :en_construction) }
      let!(:dossier_not_to_notify) { create(:dossier, :en_construction) }

      before { [dossier_to_notify, dossier_to_notify_2].each { |d| d.update(expired_at: 2.weeks.from_now) } }

      it "returns only dossiers termine or en_construction close to expiration" do
        expect(subject).to contain_exactly(dossier_to_notify, dossier_to_notify_2)
      end
    end

    context "when notification_type is dossier_suppression" do
      let(:notification_type) { :dossier_suppression }
      let!(:dossier_to_notify) { create(:dossier, :accepte, hidden_by_administration_at: Time.zone.yesterday, hidden_by_user_at: Time.zone.yesterday) }
      let!(:dossier_to_notify_2) { create(:dossier, :en_construction, hidden_by_expired_at: Time.zone.yesterday) }
      let!(:dossier_not_to_notify) { create(:dossier, :en_construction, hidden_by_administration_at: nil, hidden_by_expired_at: nil) }
      let!(:dossier_not_to_notify_2) { create(:dossier, :accepte, hidden_by_administration_at: Time.zone.yesterday) }

      it "returns only dossiers expired or hidden by administration" do
        expect(subject).to contain_exactly(dossier_to_notify, dossier_to_notify_2)
      end
    end

    context "when notification_type is dossier_modifie" do
      let(:notification_type) { :dossier_modifie }
      let!(:dossier_to_notify) { create(:dossier, depose_at: 2.days.ago, last_champ_updated_at: 1.day.ago) }
      let!(:dossier_not_to_notify_1) { create(:dossier, depose_at: 1.day.ago, last_champ_updated_at: nil) }
      let!(:dossier_not_to_notify_2) { create(:dossier, depose_at: 1.day.ago, last_champ_updated_at: 2.days.ago) }

      it "returns only dossiers modified after the submission" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end

    context "when notification_type is message" do
      let(:notification_type) { :message }
      let!(:dossier_to_notify) { create(:dossier) }
      let!(:commentaire_to_notify) { create(:commentaire, dossier: dossier_to_notify, instructeur_id: nil, email: "test@exemple.fr") }
      let!(:dossier_not_to_notify) { create(:dossier) }
      let!(:commentaire_not_to_notify) { create(:commentaire, dossier: dossier_not_to_notify, instructeur:) }

      it "returns dossiers with commentaires to notify" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end

    context "when notification_type is annotation_instructeur" do
      let(:notification_type) { :annotation_instructeur }
      let!(:dossier_to_notify) { create(:dossier, last_champ_private_updated_at: Time.current) }
      let!(:dossier_not_to_notify) { create(:dossier, last_champ_private_updated_at: nil) }

      it "returns dossiers with last_champ_private_updated_at present" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end

    context "when notification_type is avis_externe" do
      let(:notification_type) { :avis_externe }
      let!(:dossier_to_notify) { create(:dossier) }
      let!(:avis_with_answer) { create(:avis, :with_answer, dossier: dossier_to_notify) }
      let!(:dossier_not_to_notify) { create(:dossier) }
      let!(:avis_without_answer) { create(:avis, dossier: dossier_not_to_notify) }

      it "returns dossiers with avis answered" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end

    context "when notification_type is attente_correction" do
      let(:notification_type) { :attente_correction }
      let!(:dossier_to_notify) { create(:dossier) }
      let!(:commentaire_correction) { create(:commentaire, dossier: dossier_to_notify, instructeur:) }
      let!(:correction) { create(:dossier_correction, dossier: dossier_to_notify, commentaire: commentaire_correction) }
      let!(:dossier_not_to_notify) { create(:dossier) }

      it "returns dossiers with pending corrections" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end

    context "when notification_type is attente_avis" do
      let(:notification_type) { :attente_avis }
      let!(:dossier_to_notify) { create(:dossier) }
      let!(:avis_without_answer) { create(:avis, dossier: dossier_to_notify) }
      let!(:dossier_not_to_notify) { create(:dossier) }
      let!(:avis_with_answer) { create(:avis, :with_answer, dossier: dossier_not_to_notify) }

      it "returns dossiers with avis without answer" do
        expect(subject).to contain_exactly(dossier_to_notify)
      end
    end
  end

  describe '.instructeur_ids_to_notify_by_notification_type' do
    subject { DossierNotification.instructeur_ids_to_notify_by_notification_type(dossier, notification_type, instructeur_ids) }

    context "when notification_type is message" do
      let(:notification_type) { :message }
      let(:dossier) { create(:dossier) }
      let(:instructeur_to_notify) { create(:instructeur) }
      let(:instructeur_not_to_notify) { create(:instructeur) }
      let!(:commentaire_not_to_notify) { create(:commentaire, dossier:, instructeur: instructeur_not_to_notify) }
      let(:instructeur_ids) { [instructeur_to_notify, instructeur_not_to_notify].map(&:id) }

      it "returns instructeur_ids to notify" do
        expect(subject).to eq([instructeur_to_notify.id])
      end
    end
  end

  describe '.destroy_notifications' do
    context 'when instructeur unfollow a dossier' do
      subject { DossierNotification.destroy_notifications_instructeur_of_unfollowed_dossier(instructeur, dossier) }

      let_it_be(:dossier) { create(:dossier) }
      let_it_be(:instructeur) { create(:instructeur) }
      let_it_be(:message_notification) { create(:dossier_notification, instructeur:, dossier:, notification_type: :message) }

      context 'when the instructeur has default preferences for badge notification' do
        it 'destroys notification' do
          subject

          expect(DossierNotification.count).to eq(0)
        end
      end

      context 'when the instructeur wants notifications even if he is not following the dossier' do
        let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure_id: dossier.procedure.id) }

        before { instructeur_procedure.update!(display_message_notifications: 'all') }

        it 'does not destroy notification' do
          expect { subject }.not_to change { DossierNotification.count }
        end
      end

      context 'when the instructeur wants notifications on followed dossiers' do
        let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure_id: dossier.procedure.id, display_message_notifications: 'followed') }

        it 'destroys notification' do
          subject

          expect(DossierNotification.count).to eq(0)
        end
      end
    end
  end

  describe '.notifications_for' do
    let_it_be(:instructeur) { create(:instructeur) }
    let_it_be(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur]) }
    let_it_be(:other_groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur]) }
    let_it_be(:dossier) { create(:dossier, :accepte, groupe_instructeur:) }
    let_it_be(:other_dossier) { create(:dossier, :en_construction, groupe_instructeur: other_groupe_instructeur) }
    let_it_be(:notification_instructeur) { create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_modifie) }
    let_it_be(:other_notification_instructeur) { create(:dossier_notification, dossier: other_dossier, instructeur:, notification_type: :dossier_modifie) }

    context 'a given instructeur and one dossier' do
      subject { DossierNotification.notifications_for_instructeur_dossier(instructeur, dossier) }

      it 'includes correct notifications and excludes the others' do
        is_expected.to include(notification_instructeur)
        is_expected.not_to include(other_notification_instructeur)
      end
    end

    context 'a given instructeur and a list of dossiers' do
      let!(:dossier_ids) { [dossier.id, other_dossier.id] }

      subject { DossierNotification.notifications_for_instructeur_dossiers(instructeur, dossier_ids) }

      it 'includes correct notifications and excludes the others' do
        expect(subject[dossier.id]).to include(notification_instructeur)
        expect(subject[other_dossier.id]).to include(other_notification_instructeur)
      end
    end

    context 'a given instructeur on a procedure' do
      let!(:groupe_instructeur_ids) { [groupe_instructeur.id, other_groupe_instructeur.id] }

      subject { DossierNotification.notifications_for_instructeur_procedure(groupe_instructeur_ids, instructeur) }

      it 'includes correct notifications and excludes the others' do
        expect(subject['traites']['dossier_modifie']).to include(dossier)
        expect(subject['a-suivre']['dossier_modifie']).to include(other_dossier)
      end
    end
  end

  describe '.notifications_sticker_for' do
    let_it_be(:procedure) { create(:procedure) }
    let_it_be(:instructeur, reload: true) { create(:instructeur) }
    let_it_be(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur]) }
    let_it_be(:other_groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur]) }
    let_it_be(:dossier) { create(:dossier, :accepte, procedure:, groupe_instructeur:) }
    let_it_be(:other_dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur: other_groupe_instructeur) }
    let_it_be(:notification_news_instructeur) { create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_modifie) }
    let_it_be(:notification_not_news_instructeur) { create(:dossier_notification, dossier:, instructeur:) }
    let_it_be(:other_notification_news_instructeur) { create(:dossier_notification, dossier: other_dossier, instructeur:, notification_type: :annotation_instructeur) }
    let_it_be(:other_notification_not_news_instructeur) { create(:dossier_notification, dossier: other_dossier, instructeur:) }

    context 'a given instructeur on one dossier' do
      subject { DossierNotification.notifications_sticker_for_instructeur_dossier(instructeur, dossier) }

      it do
        is_expected.to eq({
          demande: true,
          annotations_privees: false,
          avis_externe: false,
          messagerie: false,
        })
      end
    end

    context 'a given instructeur on one procedure' do
      let!(:groupe_instructeur_ids) { [groupe_instructeur.id, other_groupe_instructeur.id] }
      let!(:dossier_ids) { [dossier.id, other_dossier.id] }

      subject { DossierNotification.notifications_sticker_for_instructeur_procedure(groupe_instructeur_ids, instructeur) }

      before do
        instructeur.followed_dossiers << other_dossier
      end

      it do
        is_expected.to eq({
          a_suivre: false,
          suivis: true,
          traites: true,
        })
      end
    end

    context 'a given instructeur on a list of procedures' do
      let!(:groupe_instructeur_ids) { [groupe_instructeur.id, other_groupe_instructeur.id] }

      subject { DossierNotification.notifications_sticker_for_instructeur_procedures(groupe_instructeur_ids, instructeur) }

      before do
        instructeur.followed_dossiers << other_dossier
      end

      it do
        is_expected.to eq({
          a_suivre: [],
          suivis: [procedure.id],
          traites: [procedure.id],
        })
      end
    end
  end
end
