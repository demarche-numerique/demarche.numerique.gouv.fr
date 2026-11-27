# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261110backfillDossierLinkChampProcedureIdTask do
    describe "#process" do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
      let(:dossier) { create(:dossier, :en_construction, procedure:) }
      let(:champ) { dossier.public_root_champs.first }
      let(:other_champ) { create(:dossier, :en_construction, procedure:).public_root_champs.first }
      let(:linked) { dossiers.en_construction.tap { it.update_columns(depose_at: Time.zone.local(2026, 3, 4, 0, 30)) } }
      let(:task) { described_class.new }

      def legacy!(champ, value) = champ.update_columns(value:, value_json: nil)

      def range_start(id) = id - id % described_class::RANGE_SIZE

      def process! = task.process(range_start(champ.id))

      def process_both! = task.process(range_start([champ.id, other_champ.id].min))

      def snapshot(procedure, submitted_on = nil)
        { 'procedure_id' => procedure.id, 'submitted_on' => submitted_on, 'procedure_title' => procedure.libelle, 'procedure_agency' => procedure.organisation_name }.compact
      end

      def stored(dossier) = snapshot(dossier.procedure, dossier.depose_at.to_date.iso8601)

      it "stores the snapshot of the linked dossier" do
        legacy!(champ, linked.id.to_s)

        process!

        expect(champ.reload.value_json).to eq(snapshot(linked.procedure, '2026-03-04'))
      end

      ['abc', '12 abc'].each do |value|
        it "stores nothing for #{value}" do
          legacy!(champ, value)

          expect { process! }.not_to raise_error
          expect(champ.reload.value_json).to be_nil
        end
      end

      it "backfills the valid champs of a batch holding an out of range number" do
        legacy!(champ, linked.id.to_s)
        legacy!(other_champ, '99999999999999999999')

        process_both!

        expect(champ.reload.value_json).to eq(stored(linked))
        expect(other_champ.reload.value_json).to be_nil
      end

      it "leaves alone the champs past the end of the range" do
        legacy!(champ, linked.id.to_s)

        task.process(champ.id - described_class::RANGE_SIZE)

        expect(champ.reload.value_json).to be_nil
      end

      it "backfills every slice of the range" do
        stub_const("#{described_class}::SLICE_SIZE", 1)
        other_linked = create(:dossier, :en_construction)
        legacy!(champ, linked.id.to_s)
        legacy!(other_champ, other_linked.id.to_s)

        process_both!

        expect(champ.reload.value_json).to eq(stored(linked))
        expect(other_champ.reload.value_json).to eq(stored(other_linked))
      end

      it "reads a leading zero value as the dossier number" do
        legacy!(champ, "0#{linked.id}")

        process!

        expect(champ.reload.value_json).to eq(stored(linked))
      end

      it "backfills two champs of a slice linked to the same dossier" do
        legacy!(champ, linked.id.to_s)
        legacy!(other_champ, linked.id.to_s)

        process_both!

        expect(champ.reload.value_json).to eq(stored(linked))
        expect(other_champ.reload.value_json).to eq(stored(linked))
      end

      it "does not rewrite a champ already holding the procedure and the submission date" do
        champ.update_columns(value: linked.id.to_s, value_json: stored(linked))

        expect(count_queries(matching: /UPDATE "champs"/) { process! }).to eq(0)
      end

      it "corrects a champ holding another procedure" do
        champ.update_columns(value: linked.id.to_s, value_json: { procedure_id: 0, submitted_on: linked.depose_at.to_date.iso8601 })

        process!

        expect(champ.reload.value_json).to eq(stored(linked))
      end

      it "does not touch updated_at" do
        legacy!(champ, linked.id.to_s)

        expect { process! }.not_to(change { champ.reload.updated_at })
      end

      it "is idempotent" do
        legacy!(champ, linked.id.to_s)
        process!

        expect { process! }.not_to(change { champ.reload.value_json })
      end

      it "backfills the champs of a buffer stream" do
        buffer_champ = nil
        dossier.with_update_stream(dossier.user) do
          buffer_champ = dossier.public_champ_for_update(champ.public_id, updated_by: dossier.user.email)
          buffer_champ.update!(value: linked.id)
        end
        expect(buffer_champ.stream).to eq(Dossier::USER_BUFFER_STREAM)
        legacy!(buffer_champ, linked.id.to_s)

        task.process(range_start(buffer_champ.id))

        expect(buffer_champ.reload.value_json).to eq(stored(linked))
      end

      it "leaves alone a champ linked to another dossier between the read and the write" do
        other = create(:dossier, :en_construction)
        legacy!(champ, linked.id.to_s)
        allow(Champs::DossierLinkChamp).to receive(:linked_value_jsons).and_wrap_original do |original, *args|
          original.call(*args).tap { champ.update_columns(value: other.id.to_s, value_json: stored(other)) }
        end

        process!

        expect(champ.reload.value_json).to eq(stored(other))
      end
    end

    describe "#collection" do
      let!(:champ) { create(:dossier, procedure: create(:procedure, public_type_de_champs: [{ type: :dossier_link }])).public_root_champs.first }

      it "starts the ranges on multiples of the range size" do
        ranges = described_class.new.collection

        expect(ranges).to all(satisfy { (it % described_class::RANGE_SIZE).zero? })
        expect(ranges.any? { (it...(it + described_class::RANGE_SIZE)).cover?(champ.id) }).to be(true)
      end
    end
  end
end
