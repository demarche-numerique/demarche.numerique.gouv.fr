# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260128desarchiveNotTermineDossiersTask do
    describe "#collection" do
      subject(:collection) { described_class.collection }

      let!(:dossier_archived_en_construction) { create(:dossier, :en_construction) }
      let!(:dossier_archived_en_instruction) { create(:dossier, :en_instruction) }
      let!(:dossier_archived_accepte) { create(:dossier, :accepte, :archived) }
      let!(:dossier_archived_refuse) { create(:dossier, :refuse, :archived) }
      let!(:dossier_archived_sans_suite) { create(:dossier, :sans_suite, :archived) }
      let!(:dossier_not_archived_en_construction) { create(:dossier, :en_construction) }

      before do
        dossier_archived_en_construction.update_columns(archived: true, archived_at: 1.day.ago, archived_by: "instructeur@example.com")
        dossier_archived_en_instruction.update_columns(archived: true, archived_at: 1.day.ago, archived_by: "instructeur@example.com")
      end

      it "includes only archived dossiers that are not termine" do
        expect(collection).to include(dossier_archived_en_construction)
        expect(collection).to include(dossier_archived_en_instruction)
        expect(collection).not_to include(dossier_archived_accepte)
        expect(collection).not_to include(dossier_archived_refuse)
        expect(collection).not_to include(dossier_archived_sans_suite)
        expect(collection).not_to include(dossier_not_archived_en_construction)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(dossier) }

      let(:dossier) { create(:dossier, :en_construction) }

      before do
        dossier.update_columns(archived: true, archived_at: 1.day.ago, archived_by: "instructeur@example.com")
      end

      it "unarchives the dossier" do
        expect { subject }.to change { dossier.reload.archived }.from(true).to(false)
      end

      it "clears archived_at" do
        expect { subject }.to change { dossier.reload.archived_at }.to(nil)
      end

      it "clears archived_by" do
        expect { subject }.to change { dossier.reload.archived_by }.to(nil)
      end
    end
  end
end
