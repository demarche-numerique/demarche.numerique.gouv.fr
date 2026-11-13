# frozen_string_literal: true

module Maintenance
  RSpec.describe T20261015backfillPublishedRevisionPublishedAtTask do
    let(:procedure) { procedures.individual }
    let(:published_revision) { procedure.published_revision }

    before { published_revision.update_columns(published_at: nil) }

    describe "#collection" do
      subject(:collection) { described_class.collection.where(procedure:) }

      it "holds the published revision without date, not the draft" do
        expect(collection).to eq([published_revision])
      end
    end

    describe "#process" do
      it "dates the revision when the next draft was cloned, at its publication" do
        described_class.process(published_revision)

        expect(published_revision.reload.published_at).to eq(procedure.draft_revision.created_at)
      end
    end
  end
end
