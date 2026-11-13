# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261111clearLegacyExportOrderTask do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [{ libelle: 'a' }, { libelle: 'b' }, { libelle: 'c' }])
    end

    before { procedure.update!(legacy_export_order: true) }

    describe "#collection" do
      it "holds the procedures keeping the legacy export order, hidden ones included" do
        procedure.discard!
        expect(described_class.new.collection).to include(procedure)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(Procedure.find(procedure.id)) }

      it "clears the flag when the legacy order is the same as the form's" do
        expect { process }.to change { procedure.reload.legacy_export_order }.from(true).to(false)
      end

      context "when a type de champ removed keeps its position" do
        before do
          procedure.draft_revision.remove_type_de_champ(procedure.draft_revision.public_root_type_de_champs.first.stable_id)
          procedure.publish_revision!(procedure.administrateurs.first)
        end

        it "keeps the flag" do
          expect { process }.not_to change { procedure.reload.legacy_export_order }
        end
      end
    end
  end
end
