# frozen_string_literal: true

describe ResetExpiringDossiersJob do
  subject { described_class.new(procedure).perform_now }

  around { |example| travel_to(Time.zone.local(2023, 6, 15, 12, 0, 0)) { example.run } }

  let(:duree_conservation_dossiers_dans_ds) { 2 }
  let(:procedure) { create(:procedure, duree_conservation_dossiers_dans_ds:) }

  let!(:expiring_dossier_brouillon) { create(:dossier, :brouillon, procedure: procedure, brouillon_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
  let!(:expiring_dossier_en_construction) { create(:dossier, :en_construction, procedure: procedure, en_construction_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
  let!(:expiring_dossier_termine) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
  let!(:automatic_expiring_dossier) { create(:dossier, :accepte, procedure:, termine_close_to_expiration_notice_sent_at: 3.weeks.ago, hidden_by_expired_at: 1.week.ago) }
  let!(:not_expiring_dossier) { create(:dossier, :accepte, procedure:, processed_at: 1.month.ago) }

  describe '.perform_now' do
    it 'resets flags' do
      subject

      expect(expiring_dossier_brouillon.reload.brouillon_close_to_expiration_notice_sent_at).to eq(nil)
      expect(expiring_dossier_en_construction.reload.en_construction_close_to_expiration_notice_sent_at).to eq(nil)
      expect(expiring_dossier_termine.reload.termine_close_to_expiration_notice_sent_at).to eq(nil)
      expect(expiring_dossier_brouillon.expired_at).to be_within(1.hour).of(2.months.from_now)
      expect(expiring_dossier_en_construction.expired_at).to be_within(1.hour).of(2.months.from_now)
      expect(expiring_dossier_termine.expired_at).to be_within(1.hour).of(2.months.from_now)
      expect(automatic_expiring_dossier.reload.hidden_by_expired_at).to eq(nil)
      expect(not_expiring_dossier.reload.expired_at).to be_within(1.hour).of(1.month.from_now)
    end

    it 'destroys dossier_expirant notification' do
      notif_expirant_dossier_en_construction = create(:dossier_notification, dossier: expiring_dossier_en_construction, notification_type: :dossier_expirant)
      notif_expirant_dossier_termine = create(:dossier_notification, dossier: expiring_dossier_termine, notification_type: :dossier_expirant)

      subject

      expect(DossierNotification.count).to eq(0)
    end

    context "when the dossier is hidden" do
      let!(:hidden_dossier) { create(:dossier, :accepte, procedure:, termine_close_to_expiration_notice_sent_at: 3.weeks.ago) }
      let!(:notification_suppression) { create(:dossier_notification, dossier: hidden_dossier, notification_type: :dossier_suppression) }

      it "destroys dossier_suppression if the dossier is already hidden by expired" do
        hidden_dossier.update(hidden_by_expired_at: 1.week.ago)
        subject

        expect(DossierNotification.count).to eq(0)
      end

      it "does not destroy dossier_suppression notification if the dossier is hidden by administraiton" do
        hidden_dossier.update(hidden_by_administration_at: 2.weeks.ago)
        subject

        expect(DossierNotification.all).to include(notification_suppression)
      end
    end
  end
end
