# frozen_string_literal: true

require "rails_helper"

module Maintenance
  describe T20260930BackfillTrashedBrouillonRemovalStageTask do
    let(:trash_period) { Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks }
    let(:hidden_at) { Time.zone.parse('2026-09-01 10:00') }

    # Rows written by the previous code: without the callback.
    def written_before_deploy(dossier, **columns)
      dossier.tap { it.update_columns(**columns) }
    end

    def backfilled_ids
      described_class.collection.flat_map(&:ids)
    end

    describe '#collection' do
      it 'selects the brouillons whose stage disagrees with their hiding dates only' do
        trashed = written_before_deploy(dossiers.brouillon, hidden_by_user_at: hidden_at)
        restored = create(:dossier, :brouillon).tap { it.hide_and_keep_track!(it.user, :user_request) }
        written_before_deploy(restored, hidden_by_user_at: nil)
        trashed_en_construction = written_before_deploy(dossiers.en_construction, hidden_by_user_at: hidden_at)
        already_staged = create(:dossier, :brouillon).tap { it.hide_and_keep_track!(it.user, :user_request) }

        expect(backfilled_ids).to include(trashed.id, restored.id)
        expect(backfilled_ids).not_to include(trashed_en_construction.id, already_staged.id)
      end
    end

    describe '#process' do
      def process(dossier)
        described_class.process(Dossier.where(id: dossier))
        dossier.reload
      end

      it 'dates the purge from the first hiding' do
        brouillon = written_before_deploy(dossiers.brouillon, hidden_by_expired_at: hidden_at, hidden_by_user_at: hidden_at + 1.day)

        expect(process(brouillon)).to have_attributes(removal_stage: 'hidden', removal_due_at: hidden_at + trash_period)
        expect(brouillon.trash_purge_at).to eq(brouillon.removal_due_at)
      end

      # Like trash_purge_at: 14 days in Paris time, 337 hours across the switch to winter time.
      it 'counts the trash period in Paris time across a change of daylight saving time' do
        hidden_before_winter_time = Time.zone.parse('2026-10-20 10:00')
        brouillon = written_before_deploy(dossiers.brouillon, hidden_by_user_at: hidden_before_winter_time)

        expect(process(brouillon).removal_due_at).to eq(Time.zone.parse('2026-11-03 10:00'))
        expect(brouillon.trash_purge_at).to eq(brouillon.removal_due_at)
      end

      it 'gives a brouillon restored by the previous code back to the legacy columns' do
        restored = create(:dossier, :brouillon).tap { it.hide_and_keep_track!(it.user, :user_request) }
        written_before_deploy(restored, hidden_by_user_at: nil)

        expect(process(restored)).to have_attributes(removal_stage: nil, removal_due_at: nil)
      end
    end
  end
end
