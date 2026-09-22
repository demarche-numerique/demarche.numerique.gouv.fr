# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260922backfillBrouillonRemovalStageTask do
    let(:procedure) { procedures.individual }
    let(:user) { users.usager }
    # Both sides of the end of DST (2026-10-25): two weeks earlier is 14 days
    # and one hour in UTC, as Ruby computes it.
    let(:expired_at) { Time.zone.local(2026, 11, 2, 22) }
    let(:notice_at) { Time.zone.local(2026, 10, 20, 22) }

    # A brouillon from before the removal stage existed.
    def legacy_brouillon(**columns)
      create(:dossier, procedure:, user:).tap do
        it.update_columns(removal_stage: nil, removal_due_at: nil, expired_at:, **columns)
      end
    end

    def run!(*dossiers, resync: false)
      task = described_class.new.tap { it.resync = resync }
      dossiers.map { it.id / described_class::RANGE_SIZE * described_class::RANGE_SIZE }.uniq.each { task.process(it) }
    end

    def removal(dossier) = dossier.reload.then { [it.removal_stage, it.removal_due_at] }

    describe "#process" do
      it "derives the stage and its due date from the legacy columns" do
        retained = legacy_brouillon
        warned = legacy_brouillon(brouillon_close_to_expiration_notice_sent_at: notice_at, expired_at: notice_at + 2.weeks)
        hidden = legacy_brouillon(brouillon_close_to_expiration_notice_sent_at: notice_at, hidden_by_user_at: notice_at + 3.days, hidden_by_expired_at: notice_at + 1.day)

        run!(retained, warned, hidden)

        expect(removal(retained)).to eq(['retained', expired_at - 2.weeks])
        expect(removal(warned)).to eq(['warned', notice_at + 2.weeks])
        # The purge cron takes it two weeks after its earliest hiding.
        expect(removal(hidden)).to eq(['hidden', notice_at + 1.day + 2.weeks])
      end

      it "computes expired_at when it is missing" do
        dossier = legacy_brouillon(expired_at: nil)

        run!(dossier)

        expect(dossier.reload.expired_at).to eq(dossier.expiration_date)
        expect(removal(dossier)).to eq(['retained', dossier.expiration_date - 2.weeks])
      end

      it "leaves the other dossiers and the brouillons which have a stage, without dating them" do
        staged = legacy_brouillon.tap { it.update_columns(removal_stage: 'warned', removal_due_at: notice_at) }
        submitted = legacy_brouillon.tap { it.update_columns(state: Dossier.states.fetch(:en_construction)) }
        adopted = legacy_brouillon

        expect { run!(staged, submitted, adopted) }.not_to change { adopted.reload.updated_at }

        expect(removal(staged)).to eq(['warned', notice_at])
        expect(removal(submitted)).to eq([nil, nil])
      end

      context "with resync" do
        it "re-derives the brouillons which drifted and clears the stage out of brouillon" do
          # Trashed by a request which loaded it before its adoption.
          trashed = legacy_brouillon.tap { run!(it) }
          trashed.update_columns(hidden_by_user_at: notice_at)
          in_sync = legacy_brouillon(brouillon_close_to_expiration_notice_sent_at: notice_at).tap { run!(it) }
          submitted = legacy_brouillon.tap { it.update_columns(state: Dossier.states.fetch(:en_construction), removal_stage: 'retained') }

          expect { run!(trashed, submitted, in_sync) }.not_to change { removal(trashed) }

          run!(trashed, submitted, in_sync, resync: true)

          expect(removal(trashed)).to eq(['hidden', notice_at + 2.weeks])
          expect(removal(submitted)).to eq([nil, nil])
          expect(removal(in_sync)).to eq(['warned', notice_at + 2.weeks])
        end
      end
    end

    describe "#collection" do
      it "covers every id up to the last dossier, from 0 so that a resumed run gets the same ranges" do
        ranges = described_class.new.collection

        expect(ranges.first).to eq(0)
        expect(ranges.each_cons(2).all? { |a, b| b - a == described_class::RANGE_SIZE }).to be(true)
        expect(ranges.last + described_class::RANGE_SIZE).to be > Dossier.maximum(:id)
      end
    end
  end
end
