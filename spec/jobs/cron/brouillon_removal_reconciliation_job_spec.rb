# frozen_string_literal: true

describe Cron::BrouillonRemovalReconciliationJob do
  let(:procedure) { procedures.individual }
  let(:user) { users.usager }
  # Both sides of the end of DST (2026-10-25): the notice and the purge dates
  # are 14 days ± 1 hour away in UTC.
  let(:created_at) { Time.zone.local(2026, 8, 1, 22) }
  let(:hidden_at) { Time.zone.local(2026, 10, 20, 22) }

  # One brouillon per stage, moved by the events, and the seeded world.
  let!(:retained) { travel_to(created_at) { create(:dossier, procedure:, user:) } }
  let!(:warned) { travel_to(created_at) { create(:dossier, :warned, procedure:, user:, warned_at: hidden_at) } }
  let!(:hidden) do
    travel_to(created_at) { create(:dossier, procedure:, user:) }.tap do |dossier|
      travel_to(hidden_at) { dossier.hide_and_keep_track!(user, :user_request) }
    end
  end

  let(:in_sync) do
    {
      without_stage: 0,
      hidden_without_hiding: 0,
      hiding_without_hidden: 0,
      warned_without_notice: 0,
      notice_without_warned: 0,
      retained_due_at: 0,
      warned_due_at: 0,
      hidden_due_at: 0,
      unmanaged_with_stage: 0,
    }
  end

  before { allow(Sentry).to receive(:capture_message) }

  describe "#drift_counts" do
    # The job reads every dossier; the counts are asserted on the three
    # dossiers of the example, as an operator would scope them to a procedure.
    subject(:counts) { described_class.new.drift_counts(Dossier.where(id: [retained, warned, hidden])) }

    it "counts nothing while every dossier keeps its invariants" do
      # The notice date of the retained brouillon is on the other side of DST.
      expect((retained.expired_at - 2.weeks).utc_offset).not_to eq(retained.expired_at.utc_offset)

      expect(counts).to eq(in_sync)
    end

    {
      without_stage: -> { retained.update_columns(removal_stage: nil, removal_due_at: nil) },
      hidden_without_hiding: -> { hidden.update_columns(hidden_by_user_at: nil) },
      hiding_without_hidden: -> { retained.update_columns(hidden_by_user_at: hidden_at) },
      warned_without_notice: -> { warned.update_columns(brouillon_close_to_expiration_notice_sent_at: nil) },
      notice_without_warned: -> { retained.update_columns(brouillon_close_to_expiration_notice_sent_at: hidden_at) },
      retained_due_at: -> { retained.update_columns(expired_at: retained.expired_at + 1.day) },
      warned_due_at: -> { warned.update_columns(expired_at: warned.expired_at + 1.day) },
      hidden_due_at: -> { hidden.update_columns(removal_due_at: hidden.removal_due_at + 1.hour) },
      unmanaged_with_stage: -> { retained.update_columns(state: Dossier.states.fetch(:en_construction)) },
    }.each do |invariant, drift|
      it "counts #{invariant}" do
        instance_exec(&drift)

        expect(counts).to eq(in_sync.merge(invariant => 1))
      end
    end
  end

  describe "#perform" do
    let(:job) { described_class.new }

    it "stays silent while nothing drifts" do
      allow(job).to receive(:drift_counts).and_return(in_sync)

      job.perform_now

      expect(Sentry).not_to have_received(:capture_message)
    end

    it "reports a drift under one static title, the counts in extras" do
      drifting = in_sync.merge(without_stage: 1)
      allow(job).to receive(:drift_counts).and_return(drifting)

      job.perform_now

      expect(Sentry).to have_received(:capture_message)
        .with("Brouillon removal stage out of sync", level: :warning, extra: drifting)
    end
  end
end
