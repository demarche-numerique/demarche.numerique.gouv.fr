# frozen_string_literal: true

require "rails_helper"

module Maintenance
  describe T20261001BackfillWarnedBrouillonRemovalStageTask do
    let(:notice_period) { Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks }
    let(:noticed_at) { Time.zone.parse('2026-09-01 22:00') }

    # Rows written by the previous code: without the callback.
    def written_before_deploy(dossier, **columns)
      dossier.tap { it.update_columns(**columns) }
    end

    def warned(dossier)
      dossier.tap { it.update!(brouillon_close_to_expiration_notice_sent_at: noticed_at) }
    end

    def backfilled_ids
      described_class.collection.flat_map(&:ids)
    end

    describe '#collection' do
      it 'selects the brouillons out of the trash whose stage disagrees with their notice only' do
        noticed = written_before_deploy(dossiers.brouillon, brouillon_close_to_expiration_notice_sent_at: noticed_at)
        edited = written_before_deploy(warned(create(:dossier, :brouillon)), brouillon_close_to_expiration_notice_sent_at: nil)
        already_warned = warned(create(:dossier, :brouillon))
        trashed = create(:dossier, :brouillon).tap { it.hide_and_keep_track!(it.user, :user_request) }
        written_before_deploy(trashed, brouillon_close_to_expiration_notice_sent_at: noticed_at)
        noticed_en_construction = written_before_deploy(dossiers.en_construction, brouillon_close_to_expiration_notice_sent_at: noticed_at)

        expect(backfilled_ids).to include(noticed.id, edited.id)
        expect(backfilled_ids).not_to include(already_warned.id, trashed.id, noticed_en_construction.id)
      end
    end

    describe '#process' do
      def process(dossier)
        described_class.process(Dossier.where(id: dossier))
        dossier.reload
      end

      it 'dates the destruction a notice period after the notice' do
        brouillon = written_before_deploy(dossiers.brouillon, brouillon_close_to_expiration_notice_sent_at: noticed_at)

        expect(process(brouillon)).to have_attributes(removal_stage: 'warned', removal_due_at: noticed_at + notice_period)
        expect(brouillon.notice_deletion_at).to eq(brouillon.removal_due_at)
      end

      # Like notice_deletion_at: 14 days in Paris time, 337 hours across the switch to winter time.
      it 'counts the notice period in Paris time across a change of daylight saving time' do
        noticed_before_winter_time = Time.zone.parse('2026-10-20 22:00')
        brouillon = written_before_deploy(dossiers.brouillon, brouillon_close_to_expiration_notice_sent_at: noticed_before_winter_time)

        expect(process(brouillon).removal_due_at).to eq(Time.zone.parse('2026-11-03 22:00'))
        expect(brouillon.notice_deletion_at).to eq(brouillon.removal_due_at)
      end

      it 'gives a brouillon edited by the previous code back to the legacy columns' do
        edited = written_before_deploy(warned(create(:dossier, :brouillon)), brouillon_close_to_expiration_notice_sent_at: nil)

        expect(process(edited)).to have_attributes(removal_stage: nil, removal_due_at: nil)
      end
    end
  end
end
