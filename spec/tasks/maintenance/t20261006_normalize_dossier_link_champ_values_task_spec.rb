# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261006NormalizeDossierLinkChampValuesTask do
    before_all { seed "cases/champs" }

    let(:dossier) { dossiers.tous_champs }
    let(:champ) { dossier.champ_data.find { it.is_a?(Champs::DossierLinkChamp) && !it.private? } }
    let(:long_ago) { Time.zone.local(2024, 1, 1) }

    # The format validation now rejects these values: plant them in SQL, backdated.
    def plant(value, on: champ)
      ChampData.where(id: on.id).update_all(["value = ?, updated_at = ?", value, long_ago])
      Dossier.where(id: dossier.id).update_all(updated_at: long_ago)
    end

    def run!(on: champ) = described_class.new.process(on.stable_id)

    def row_version(record) = ChampData.where(id: record.id).pick(Arel.sql("ctid::text"))

    def exposed? = Dossier.where(id: dossier.id).updated_since(long_ago.next_day).exists?

    describe "#process" do
      it "keeps the number when it is the only one" do
        plant(" n° 0034217270 fvfez")

        expect { run! }.to change { champ.reload.value }.to("34217270")
      end

      # The integrators sync through updatedSince, which reads dossiers.updated_at.
      it "dates the dossier, not the champ" do
        plant("34217270 fvfez")

        expect { run! }.to change { exposed? }.to(true)
        expect(champ.reload.updated_at).to eq(long_ago)
      end

      ["34217270  34197685", "2023-1234", "34 217 270", "voir PJ", "0 abc"].each do |value|
        it "leaves #{value.inspect} for the usager to fix" do
          plant(value)

          expect { run! }.not_to change { row_version(champ) }
          expect(exposed?).to be(false)
        end
      end

      it "does not rewrite the rows that are already clean" do
        plant("34217270")

        expect { run! }.not_to change { row_version(champ) }
      end

      it "leaves the history snapshots as they were typed" do
        plant("34217270 fvfez")
        history = champ.reload.dup.tap { it.stream = "#{Dossier::HISTORY_STREAM}2026-07-01" }.tap { it.save!(validate: false) }

        expect { run! }.not_to change { history.reload.value }
      end

      it "leaves the other champ types alone" do
        text = dossier.champ_data.find { it.is_a?(Champs::TextChamp) && !it.private? }
        plant("34217270 fvfez", on: text)

        expect { run!(on: text) }.not_to change { text.reload.value }
      end
    end

    describe "#collection" do
      it "lists the dossier link stable ids" do
        expect(described_class.new.collection).to include(champ.stable_id)
      end
    end
  end
end
