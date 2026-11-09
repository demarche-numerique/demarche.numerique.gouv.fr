# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261109purgeChampOrphanAttachmentsTask do
    let(:champ) { dossiers.en_construction.champ_data.first }
    let(:missing_champ_id) { ChampData.maximum(:id) + 1_000 }

    def attach_to_champ
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("pj"), filename: "pj.txt")
      ActiveStorage::Attachment.create!(name: "piece_justificative_file", record: champ, blob:)
    end

    let!(:orphan) { attach_to_champ.tap { it.update_columns(record_id: missing_champ_id) } }
    let!(:attached) { attach_to_champ }

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      it "starts from a fixed origin, so a resumed run keeps the same ranges" do
        expect(collection.first).to eq(1)
      end

      it "ends with the range holding the last attachment" do
        expect(collection.last..(collection.last + described_class::RANGE_SIZE - 1)).to cover(attached.id)
      end
    end

    describe "#process" do
      subject(:process) { described_class.new.process(orphan.id) }

      it "purges only the attachments whose champ is gone" do
        expect { process }.to have_enqueued_job(DelayedPurgeJob).with(orphan.blob)

        expect(ActiveStorage::Attachment.where(id: [orphan, attached])).to contain_exactly(attached)
      end
    end
  end
end
