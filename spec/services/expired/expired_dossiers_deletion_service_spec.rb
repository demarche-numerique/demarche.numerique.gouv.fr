# frozen_string_literal: true

describe Expired::DossiersDeletionService do
  let(:warning_period) { 2.weeks }
  let(:conservation_par_defaut) { 3.months }
  let(:user) { create(:user) }
  let(:procedure_opts) { {} }
  let(:procedure) { create(:procedure, :published, procedure_opts) }
  let(:procedure_2) { create(:procedure, :published, :new_administrateur, procedure_opts) }
  let(:reference_date) { Date.parse("March 8") }
  let(:service) { Expired::DossiersDeletionService.new }

  describe '#process_expired_dossiers_brouillon' do
    before { travel_to(reference_date) }

    let(:today) { Time.zone.now.at_beginning_of_day }
    let(:date_close_to_expiration) { today - procedure.duree_conservation_dossiers_dans_ds.months + 13.days }
    let(:date_expired) { today - procedure.duree_conservation_dossiers_dans_ds.months - 6.days }
    let(:date_not_expired) { today - procedure.duree_conservation_dossiers_dans_ds.months + 2.months }

    context 'send messages for dossiers expiring soon and delete expired' do
      let!(:expired_brouillon) { create(:dossier, procedure: procedure, updated_at: date_expired, brouillon_close_to_expiration_notice_sent_at: today - (warning_period + 3.days)) }
      let!(:brouillon_close_to_expiration) { create(:dossier, procedure: procedure, updated_at: date_close_to_expiration) }
      let!(:brouillon_close_but_with_notice_sent) { create(:dossier, procedure: procedure, updated_at: date_close_to_expiration, brouillon_close_to_expiration_notice_sent_at: Time.zone.now) }
      let!(:valid_brouillon) { create(:dossier, procedure: procedure, updated_at: date_not_expired) }

      before do
        allow(DossierMailer).to receive(:notify_brouillon_near_deletion).and_call_original
        allow(DossierMailer).to receive(:notify_brouillon_deletion).and_call_original

        service.process_expired_dossiers_brouillon
      end

      it 'emails should be sent' do
        expect(DossierMailer).to have_received(:notify_brouillon_near_deletion).once
        expect(DossierMailer).to have_received(:notify_brouillon_near_deletion).with([brouillon_close_to_expiration], brouillon_close_to_expiration.user.email)
      end

      it 'dossier brouillon_close_to_expiration_notice_sent_at should change' do
        expect(brouillon_close_to_expiration.reload.brouillon_close_to_expiration_notice_sent_at).not_to be_nil
      end

      it 'deletes and notify expired brouillon' do
        expect(DossierMailer).to have_received(:notify_brouillon_deletion).once
        expect(DossierMailer).to have_received(:notify_brouillon_deletion).with([expired_brouillon.hash_for_deletion_mail], expired_brouillon.user.email)
        expect(DeletedDossier.find_by(dossier_id: expired_brouillon.id)).not_to be_present
        expect { expired_brouillon.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'silently drains never-notified expired brouillons' do
      let(:closed_procedure) { create(:procedure, :closed) }
      let!(:expired_on_closed) { create(:dossier, procedure: closed_procedure).tap { |d| d.update_column(:expired_at, 1.day.ago) } }

      before { service.process_expired_dossiers_brouillon }

      it 'destroys them' do
        expect { expired_on_closed.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#send_brouillon_expiration_notices' do
    before { travel_to(reference_date) }

    before do
      allow(DossierMailer).to receive(:notify_brouillon_near_deletion).and_return(double(deliver_later: nil))
    end

    context 'with a single dossier' do
      let!(:dossier) { create(:dossier, procedure: procedure, updated_at: updated_at) }

      before { service.send_brouillon_expiration_notices }

      context 'when the dossier is not close to expiration' do
        let(:updated_at) { (conservation_par_defaut - 2.weeks - 1.day).ago }

        it do
          expect(dossier.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil
          expect(DossierMailer).not_to have_received(:notify_brouillon_near_deletion)
        end
      end

      context 'when the dossier is close to expiration' do
        let(:updated_at) { (conservation_par_defaut - 2.weeks + 1.day).ago }

        it do
          expect(dossier.reload.brouillon_close_to_expiration_notice_sent_at).not_to be_nil
          expect(DossierMailer).to have_received(:notify_brouillon_near_deletion).once
          expect(DossierMailer).to have_received(:notify_brouillon_near_deletion).with([dossier], dossier.user.email)
          expect(dossier.expired_at).to be_within(1.second).of(dossier.expiration_date)
        end
      end
    end

    context 'with 2 dossiers to notice' do
      let!(:dossier_1) { create(:dossier, procedure: procedure, user: user, updated_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, procedure: procedure_2, user: user, updated_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }

      before { service.send_brouillon_expiration_notices }

      it do
        expect(DossierMailer).to have_received(:notify_brouillon_near_deletion).once
        expect(DossierMailer).to have_received(:notify_brouillon_near_deletion).with(match_array([dossier_1, dossier_2]), user.email)
      end
    end
  end

  describe '#process_never_touched_dossiers_brouillon' do
    subject { service.process_never_touched_dossiers_brouillon }

    context 'with never touched brouillon dossiers' do
      empty_seeds Dossier

      let!(:never_touched_brouillon) { travel_to(20.days.ago) { create(:dossier, procedure: procedure, last_champ_updated_at: nil) } }
      let!(:never_touched_brouillon_2) { travel_to(7.days.ago) { create(:dossier, procedure: procedure, last_champ_updated_at: nil) } }
      let!(:never_touched_en_construction) { travel_to(20.days.ago) { create(:dossier, :en_construction, procedure: procedure, last_champ_updated_at: nil) } }
      let!(:touched_brouillon) { travel_to(20.days.ago) { create(:dossier, procedure: procedure, last_champ_updated_at: 1.day.ago) } }

      it 'deletes never touched brouillons ' do
        expect { subject }.to change { Dossier.never_touched_brouillon_expired.count }.from(1).to(0)
        expect(Dossier.all).to contain_exactly(never_touched_brouillon_2, never_touched_en_construction, touched_brouillon)
      end
    end
  end

  describe '#delete_expired_brouillons_and_notify' do
    before { travel_to(reference_date) }

    before do
      allow(DossierMailer).to receive(:notify_brouillon_deletion).and_return(double(deliver_later: nil))
    end

    context 'with a single dossier' do
      let!(:dossier) { create(:dossier, procedure: procedure, brouillon_close_to_expiration_notice_sent_at: notice_sent_at) }

      before { service.delete_expired_brouillons_and_notify }

      context 'when no notice has been sent' do
        let(:notice_sent_at) { nil }

        it do
          expect { dossier.reload }.not_to raise_error
          expect(DossierMailer).not_to have_received(:notify_brouillon_deletion)
        end
      end

      context 'when a notice has been sent not so long ago' do
        let(:notice_sent_at) { (warning_period - 4.days).ago }

        it do
          expect { dossier.reload }.not_to raise_error
          expect(DossierMailer).not_to have_received(:notify_brouillon_deletion)
        end
      end

      context 'when a notice has been sent a long time ago' do
        let(:notice_sent_at) { (warning_period + 4.days).ago }

        it "works" do
          expect { dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect(DossierMailer).to have_received(:notify_brouillon_deletion).once
          expect(DossierMailer).to have_received(:notify_brouillon_deletion).with([dossier.hash_for_deletion_mail], dossier.user.email)
        end
      end
    end

    context 'with 2 dossiers to delete' do
      let!(:dossier_1) { create(:dossier, procedure: procedure, user: user, brouillon_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, procedure: procedure_2, user: user, brouillon_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      before { service.delete_expired_brouillons_and_notify }

      it "works" do
        expect(DossierMailer).to have_received(:notify_brouillon_deletion).once
        expect(DossierMailer).to have_received(:notify_brouillon_deletion).with(match_array([dossier_1.hash_for_deletion_mail, dossier_2.hash_for_deletion_mail]), user.email)
      end
    end
  end

  describe '#delete_expired_brouillons_without_notice' do
    before { travel_to(reference_date) }

    let(:closed_procedure) { create(:procedure, :closed) }
    let!(:expired_on_closed)    { create(:dossier, procedure: closed_procedure).tap { |d| d.update_column(:expired_at, 1.day.ago) } }
    let!(:notifiable_brouillon) { create(:dossier, procedure: procedure).tap { |d| d.update_column(:expired_at, 1.day.ago) } }

    before do
      allow(DossierMailer).to receive(:notify_brouillon_deletion).and_call_original
      allow(DossierMailer).to receive(:notify_brouillon_near_deletion).and_call_original
    end

    it 'silently deletes never-notified expired brouillons without sending email' do
      expect { service.delete_expired_brouillons_without_notice }
        .to change { Dossier.exists?(expired_on_closed.id) }.from(true).to(false)

      expect(DossierMailer).not_to have_received(:notify_brouillon_deletion)
      expect(DossierMailer).not_to have_received(:notify_brouillon_near_deletion)
    end

    it 'leaves notifiable brouillons untouched' do
      service.delete_expired_brouillons_without_notice
      expect { notifiable_brouillon.reload }.not_to raise_error
    end

    context 'when there are more expired brouillons than the per-day limit' do
      let!(:other_expired_on_closed) { create(:dossier, procedure: closed_procedure).tap { |d| d.update_column(:expired_at, 2.days.ago) } }

      before { stub_const("#{described_class}::BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY", 1) }

      it 'deletes at most the limit per run' do
        expect { service.delete_expired_brouillons_without_notice }
          .to change { Dossier.brouillon_expired_without_notice.count }.by(-1)
      end
    end
  end

  describe '#send_termine_expiration_notices' do
    before { travel_to(reference_date) }
    let(:procedure_opts) { {} }
    before do
      allow(DossierMailer).to receive(:notify_near_deletion_to_user).and_call_original
      allow(DossierMailer).to receive(:notify_near_deletion_for_tiers).and_call_original
      allow(DossierMailer).to receive(:notify_near_deletion_to_administration).and_call_original
    end

    context 'with a single dossier' do
      let!(:dossier) { create(:dossier, :followed, state: :accepte, procedure: procedure, processed_at: processed_at) }

      before do
        dossier.update_expired_at
        service.send_termine_expiration_notices
      end

      context 'when the dossier is not near deletion' do
        let(:processed_at) { (conservation_par_defaut - 2.weeks - 1.day).ago }

        it do
          expect(dossier.reload.termine_close_to_expiration_notice_sent_at).to be_nil
          expect(DossierMailer).not_to have_received(:notify_near_deletion_to_user)
          expect(DossierMailer).not_to have_received(:notify_near_deletion_to_administration)
        end
      end

      context 'when the dossier is near deletion' do
        let(:processed_at) { (conservation_par_defaut - 2.weeks + 1.day).ago }

        it "works" do
          expect(dossier.reload.termine_close_to_expiration_notice_sent_at).not_to be_nil
          expect(DossierMailer).to have_received(:notify_near_deletion_to_user).once
          expect(DossierMailer).to have_received(:notify_near_deletion_to_administration).once
          expect(DossierMailer).to have_received(:notify_near_deletion_to_user).with([dossier], dossier.user.email)
          expect(DossierMailer).not_to have_received(:notify_near_deletion_to_administration).with([dossier], dossier.procedure.administrateurs.first.email)
          expect(DossierMailer).to have_received(:notify_near_deletion_to_administration).with([dossier], dossier.followers_instructeurs.first.email)
          expect(dossier.expired_at).to be_within(1.second).of(dossier.expiration_date)
        end
      end
    end

    context 'with 2 dossiers to notice' do
      let!(:dossier_1) { create(:dossier, state: :accepte, procedure: procedure, user: user, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, state: :accepte, procedure: procedure_2, user: user, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }

      let!(:instructeur) { create(:instructeur) }
      let(:groupe) { procedure.groupe_instructeurs.first }

      before do
        [dossier_1, dossier_2].each(&:update_expired_at)
        instructeur.followed_dossiers << dossier_1 << dossier_2
        AssignTo.create!(groupe_instructeur: groupe, instructeur: dossier_1.procedure.administrateurs.first.instructeur)
        service.send_termine_expiration_notices
      end

      it "works" do
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).once
        expect(DossierMailer).to have_received(:notify_near_deletion_to_administration).exactly(2).times
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).with(match_array([dossier_1, dossier_2]), user.email)
        expect(DossierMailer).to have_received(:notify_near_deletion_to_administration).with(match_array([dossier_1, dossier_2]), instructeur.email)
        expect(DossierMailer).to have_received(:notify_near_deletion_to_administration).with([dossier_1], dossier_1.procedure.administrateurs.first.email)
        expect(DossierMailer).not_to have_received(:notify_near_deletion_to_administration).with([dossier_2], dossier_2.procedure.administrateurs.first.email)
      end
    end

    context 'when there are more dossiers than the per-day limit' do
      let!(:dossier_expiring_first) { create(:dossier, state: :accepte, procedure: procedure, processed_at: (conservation_par_defaut - 2.weeks + 3.days).ago) }
      let!(:dossier_expiring_later) { create(:dossier, state: :accepte, procedure: procedure, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }

      before do
        [dossier_expiring_first, dossier_expiring_later].each(&:update_expired_at)
        stub_const("#{described_class}::TERMINE_NOTICES_LIMIT_PER_DAY", 1)
        service.send_termine_expiration_notices
      end

      it 'notifies the dossiers expiring first, the rest waits for the next run' do
        expect(dossier_expiring_first.reload.termine_close_to_expiration_notice_sent_at).not_to be_nil
        expect(dossier_expiring_later.reload.termine_close_to_expiration_notice_sent_at).to be_nil
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).once
      end
    end

    context 'when a dossier was sent back to instruction after the selection' do
      let!(:dossier) { create(:dossier, :followed, state: :accepte, procedure: procedure, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }

      before do
        dossier.update_expired_at
        allow(service).to receive(:each_termine_batch).and_wrap_original do |each_termine_batch, ids_and_user_ids, &block|
          dossier.update_columns(state: Dossier.states.fetch(:en_instruction))
          each_termine_batch.call(ids_and_user_ids, &block)
        end
        service.send_termine_expiration_notices
      end

      it 'neither flags nor notifies it' do
        expect(dossier.reload.termine_close_to_expiration_notice_sent_at).to be_nil
        expect(DossierMailer).not_to have_received(:notify_near_deletion_to_user)
        expect(DossierMailer).not_to have_received(:notify_near_deletion_to_administration)
      end
    end

    context 'when a user has more dossiers than the batch size' do
      let!(:dossier_1) { create(:dossier, state: :accepte, procedure: procedure, user: user, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, state: :accepte, procedure: procedure_2, user: user, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }
      let!(:other_dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }

      before do
        [dossier_1, dossier_2, other_dossier].each(&:update_expired_at)
        stub_const("#{described_class}::TERMINE_BATCH_SIZE", 1)
        service.send_termine_expiration_notices
      end

      it 'keeps the dossiers of the user in one mail' do
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).twice
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).with(match_array([dossier_1, dossier_2]), user.email)
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).with([other_dossier], other_dossier.user.email)
      end
    end

    context 'when an instructeur is also administrateur' do
      let!(:administrateur) { procedure.administrateurs.first }
      let!(:dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }

      before do
        dossier.update_expired_at
        administrateur.instructeur.followed_dossiers << dossier
        service.send_termine_expiration_notices
      end

      it "works" do
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).once
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).with([dossier], dossier.user.email)
        expect(DossierMailer).to have_received(:notify_near_deletion_to_administration).with([dossier], administrateur.email)
      end
    end

    context "when an instructeur does not want to be notified" do
      let(:groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }
      let(:instructeur) { create(:instructeur) }
      let!(:dossier) { create(:dossier, state: :accepte, procedure:, groupe_instructeur:, user:, processed_at: (conservation_par_defaut - 2.weeks + 1.day).ago) }
      let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, instant_email_dossier_expiration: false) }

      before do
        dossier.update_expired_at
        instructeur.followed_dossiers << dossier
        service.send_termine_expiration_notices
      end

      it "does not send a notification email to the instructeur" do
        expect(DossierMailer).to have_received(:notify_near_deletion_to_user).once
        expect(DossierMailer).not_to have_received(:notify_near_deletion_to_administration).with([dossier], instructeur.user.email)
      end
    end

    context 'when the dossier is for tiers' do
      let(:procedure) { create(:procedure, :published, :for_individual) }
      let!(:dossier_for_tiers_with_notif) { create(:dossier, :accepte, :for_tiers_with_notification, procedure:, processed_at:) }
      let!(:dossier_for_tiers_without_notif) { create(:dossier, :accepte, :for_tiers_without_notification, procedure:, processed_at:) }
      let!(:dossier_not_for_tiers) { create(:dossier, :accepte, procedure:, processed_at:) }
      let(:processed_at) { (conservation_par_defaut - 2.weeks + 1.day).ago }

      before do
        [dossier_for_tiers_with_notif, dossier_for_tiers_without_notif, dossier_not_for_tiers].each(&:update_expired_at)
        service.send_termine_expiration_notices
      end

      it do
        expect(DossierMailer).to have_received(:notify_near_deletion_for_tiers).once
        expect(DossierMailer).to have_received(:notify_near_deletion_for_tiers).with(match_array([dossier_for_tiers_with_notif]), dossier_for_tiers_with_notif.individual.email)
      end
    end
  end

  describe '#delete_expired_termine_and_notify' do
    before { travel_to(reference_date) }

    let(:procedure_opts) { {} }

    before do
      allow(DossierMailer).to receive(:notify_automatic_deletion_to_user).and_call_original
      allow(DossierMailer).to receive(:notify_automatic_deletion_for_tiers).and_call_original
      allow(DossierMailer).to receive(:notify_automatic_deletion_to_administration).and_call_original
    end

    context 'with a single dossier' do
      let!(:dossier) { create(:dossier, :followed, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: notice_sent_at) }

      before { service.delete_expired_termine_and_notify }

      context 'when no notice has been sent' do
        let(:notice_sent_at) { nil }

        it "works" do
          expect { dossier.reload }.not_to raise_error
          expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_user)
          expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration)
        end
      end

      context 'when a notice has been sent not so long ago' do
        let(:notice_sent_at) { (warning_period - 4.days).ago }

        it "works" do
          expect { dossier.reload }.not_to raise_error
          expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_user)
          expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration)
        end
      end

      context 'when a notice has been sent a long time ago' do
        let(:notice_sent_at) { (warning_period + 4.days).ago }

        it "works" do
          expect(dossier.reload.hidden_by_expired_at).to be_an_instance_of(ActiveSupport::TimeWithZone)
          expect(dossier.reload.hidden_by_reason).to eq('expired')
        end

        it "works" do
          expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).once
          expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with([dossier], dossier.user.email)
        end

        it "works" do
          expect(DossierMailer).to have_received(:notify_automatic_deletion_to_administration).once
          expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration).with([dossier], dossier.procedure.administrateurs.first.email)
          expect(DossierMailer).to have_received(:notify_automatic_deletion_to_administration).with([dossier], dossier.followers_instructeurs.first.email)
        end
      end
    end

    context 'with 2 dossiers to delete' do
      let!(:dossier_1) { create(:dossier, :accepte, procedure: procedure, user: user, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, :refuse, procedure: procedure_2, user: user, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      let!(:instructeur) { create(:instructeur) }

      before do
        instructeur.followed_dossiers << dossier_1 << dossier_2
        service.delete_expired_termine_and_notify
      end

      it "works" do
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).once
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with(match_array([dossier_1, dossier_2]), user.email)
      end

      it "works" do
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_administration).once
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_administration).with(match_array([dossier_1, dossier_2]), instructeur.email)
        expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration).with([dossier_1], dossier_1.procedure.administrateurs.first.email)
        expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration).with([dossier_2], dossier_2.procedure.administrateurs.first.email)
      end

      it "works" do
        expect(dossier_1.reload.hidden_by_expired_at).to be_an_instance_of(ActiveSupport::TimeWithZone)
        expect(dossier_1.reload.hidden_by_reason).to eq('expired')
        expect(dossier_2.reload.hidden_by_expired_at).to be_an_instance_of(ActiveSupport::TimeWithZone)
        expect(dossier_2.reload.hidden_by_reason).to eq('expired')
      end
    end

    context 'when there are more dossiers than the per-day limit' do
      let!(:dossier_notified_first) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: (warning_period + 4.days).ago) }
      let!(:dossier_notified_later) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      before do
        stub_const("#{described_class}::TERMINE_DELETION_LIMIT_PER_DAY", 1)
        service.delete_expired_termine_and_notify
      end

      it 'hides the dossiers notified first, the rest waits for the next run' do
        expect(dossier_notified_first.reload.hidden_by_expired_at).not_to be_nil
        expect(dossier_notified_later.reload.hidden_by_expired_at).to be_nil
      end
    end

    context 'when the dossiers span several batches' do
      let!(:dossier_1) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      before do
        stub_const("#{described_class}::TERMINE_BATCH_SIZE", 1)
        service.delete_expired_termine_and_notify
      end

      it 'hides and notifies every batch' do
        expect(dossier_1.reload.hidden_by_expired_at).not_to be_nil
        expect(dossier_2.reload.hidden_by_expired_at).not_to be_nil
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with([dossier_1], dossier_1.user.email)
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with([dossier_2], dossier_2.user.email)
      end
    end

    context 'when a dossier was sent back to instruction after the selection' do
      let!(:dossier) { create(:dossier, :followed, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      before do
        allow(service).to receive(:each_termine_batch).and_wrap_original do |each_termine_batch, ids_and_user_ids, &block|
          dossier.update_columns(state: Dossier.states.fetch(:en_instruction))
          each_termine_batch.call(ids_and_user_ids, &block)
        end
      end

      it 'neither hides nor notifies it' do
        expect { service.delete_expired_termine_and_notify }.not_to raise_error
        expect(dossier.reload.hidden_by_expired_at).to be_nil
        expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_user)
        expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration)
      end
    end

    context 'when a user has more dossiers than the batch size' do
      let!(:dossier_1) { create(:dossier, :accepte, procedure: procedure, user: user, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, :accepte, procedure: procedure_2, user: user, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:other_dossier) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      before do
        stub_const("#{described_class}::TERMINE_BATCH_SIZE", 1)
        service.delete_expired_termine_and_notify
      end

      it 'keeps the dossiers of the user in one mail' do
        expect([dossier_1, dossier_2, other_dossier].map { it.reload.hidden_by_expired_at }).to all(be_present)
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).twice
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with(match_array([dossier_1, dossier_2]), user.email)
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with([other_dossier], other_dossier.user.email)
      end
    end

    context 'with 1 dossier deleted by user and 1 dossier deleted by administration' do
      let!(:dossier_1) { create(:dossier, :accepte, procedure: procedure, user: user, hidden_by_administration_at: 1.hour.ago, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_2) { create(:dossier, :refuse, procedure: procedure_2, user: user, hidden_by_user_at: 1.hour.ago, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      let!(:instructeur) { create(:instructeur) }

      before do
        instructeur.followed_dossiers << dossier_1 << dossier_2
        service.delete_expired_termine_and_notify
      end

      it "works" do
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).once
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).with(match_array([dossier_1]), user.email)
      end

      it "works" do
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_administration).once
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_administration).with(match_array([dossier_2]), instructeur.email)
        expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration).with([dossier_2], dossier_2.procedure.administrateurs.first.email)
      end
    end

    context "when an instructeur does not want to be notified" do
      let(:groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }
      let(:instructeur) { create(:instructeur) }
      let!(:dossier) { create(:dossier, :accepte, procedure:, groupe_instructeur:, user:, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, instant_email_dossier_expired: false) }

      before do
        instructeur.followed_dossiers << dossier
        service.delete_expired_termine_and_notify
      end

      it "does not send a notification email to the instructeur" do
        expect(DossierMailer).to have_received(:notify_automatic_deletion_to_user).once
        expect(DossierMailer).not_to have_received(:notify_automatic_deletion_to_administration).with([dossier], instructeur.user.email)
      end
    end

    context 'when the dossier is for tiers' do
      let(:procedure) { create(:procedure, :published, :for_individual) }
      let!(:dossier_for_tiers_with_notif) { create(:dossier, :accepte, :for_tiers_with_notification, procedure:, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_for_tiers_without_notif) { create(:dossier, :accepte, :for_tiers_without_notification, procedure:, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }
      let!(:dossier_not_for_tiers) { create(:dossier, :accepte, procedure:, termine_close_to_expiration_notice_sent_at: (warning_period + 1.day).ago) }

      before do
        service.delete_expired_termine_and_notify
      end

      it do
        expect(DossierMailer).to have_received(:notify_automatic_deletion_for_tiers).once
        expect(DossierMailer).to have_received(:notify_automatic_deletion_for_tiers).with(match_array([dossier_for_tiers_with_notif]), dossier_for_tiers_with_notif.individual.email)
      end
    end
  end

  describe "#update_notifications_dossiers_termine" do
    subject { service.update_notifications_dossiers_termine }

    context "when there is no notification yet for dossiers termine close to expiration" do
      let(:instructeur) { create(:instructeur) }
      let(:other_instructeur) { create(:instructeur) }
      let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur, other_instructeur]) }
      let!(:dossier) { create(:dossier, :accepte, groupe_instructeur:) }

      before { dossier.update(expired_at: 2.weeks.from_now) }

      it "creates :dossier_expirant notification for all instructeurs with the correct delay" do
        expect { subject }.to change { DossierNotification.count }.from(0).to(2)

        notifs = DossierNotification.where(notification_type: :dossier_expirant)
        expect(notifs.pluck(:dossier_id).uniq).to eq([dossier.id])
        expect(notifs.pluck(:instructeur_id)).to match_array([instructeur.id, other_instructeur.id])
        expect(notifs.pluck(:display_at).map(&:to_date).uniq).to eq([Time.zone.today])
      end
    end

    context "when the are :dossier_expirant notifications on expired dossiers" do
      let(:dossier) { create(:dossier, :accepte, termine_close_to_expiration_notice_sent_at: 2.weeks.ago) }
      let!(:notification_expirant) { create(:dossier_notification, dossier:, notification_type: :dossier_expirant) }

      it "destroys :dossier_expirant notifications" do
        expect { subject }.to change { DossierNotification.where(notification_type: :dossier_expirant).count }.from(1).to(0)
      end
    end

    context "when there are more dossiers close to expiration than the per-day limit" do
      let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [create(:instructeur)]) }
      let!(:dossier_expiring_first) { create(:dossier, :accepte, groupe_instructeur:).tap { it.update_column(:expired_at, 6.days.from_now) } }
      let!(:dossier_expiring_later) { create(:dossier, :accepte, groupe_instructeur:).tap { it.update_column(:expired_at, 13.days.from_now) } }

      before { stub_const("#{described_class}::TERMINE_NOTICES_LIMIT_PER_DAY", 1) }

      it "notifies the dossiers expiring first, the rest waits for the next run" do
        subject

        notifs = DossierNotification.where(dossier: [dossier_expiring_first, dossier_expiring_later], notification_type: :dossier_expirant)
        expect(notifs.pluck(:dossier_id)).to eq([dossier_expiring_first.id])
      end
    end

    context "when there are more expired dossiers than the per-day limit" do
      let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [create(:instructeur)]) }
      let!(:dossier_notified_first) { create(:dossier, :accepte, groupe_instructeur:, termine_close_to_expiration_notice_sent_at: 3.weeks.ago) }
      let!(:dossier_notified_later) { create(:dossier, :accepte, groupe_instructeur:, termine_close_to_expiration_notice_sent_at: (2.weeks + 1.day).ago) }

      before { stub_const("#{described_class}::TERMINE_DELETION_LIMIT_PER_DAY", 1) }

      it "notifies the dossiers notified first, the rest waits for the next run" do
        subject

        notifs = DossierNotification.where(dossier: [dossier_notified_first, dossier_notified_later], notification_type: :dossier_suppression)
        expect(notifs.pluck(:dossier_id)).to eq([dossier_notified_first.id])
      end
    end

    context "when the are new expired dossiers" do
      let(:instructeur) { create(:instructeur) }
      let(:other_instructeur) { create(:instructeur) }
      let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur, other_instructeur]) }
      let!(:dossier) { create(:dossier, :accepte, groupe_instructeur:, termine_close_to_expiration_notice_sent_at: 2.weeks.ago) }

      it "creates :dossier_suppression notification for all instructeurs with the correct delay" do
        expect { subject }.to change { DossierNotification.where(notification_type: :dossier_suppression).count }.by(2)

        notifs = DossierNotification.where(notification_type: :dossier_suppression)
        expect(notifs.pluck(:dossier_id).uniq).to eq([dossier.id])
        expect(notifs.pluck(:instructeur_id)).to match_array([instructeur.id, other_instructeur.id])
        expect(notifs.pluck(:display_at).map(&:to_date).uniq).to eq([Time.zone.today])
      end
    end
  end

  describe 'all_user_dossiers_brouillon_close_to_expiration' do
    before { travel_to(reference_date) }

    let(:today) { Time.zone.now.at_beginning_of_day }
    let(:date_expired) { today - procedure.duree_conservation_dossiers_dans_ds.months - 6.days }
    let(:user) { create(:user) }
    let!(:expired_brouillon_1) { create(:dossier, procedure:, user:, updated_at: date_expired) }
    let!(:expired_brouillon_2) { create(:dossier, procedure:, user:, updated_at: date_expired) }

    it 'find additional dossiers' do
      expired_brouillon_1
      expired_brouillon_2
      expect(Expired::DossiersDeletionService.new.send(:all_user_dossiers_brouillon_close_to_expiration, user))
        .to contain_exactly(expired_brouillon_1, expired_brouillon_2)
    end
  end
end
