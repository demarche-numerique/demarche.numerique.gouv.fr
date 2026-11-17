# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe CreateVariantsForPjsFromMessagerieTask, :external_deps do
    describe "#process" do
      let(:procedure) { create(:procedure_with_dossiers) }
      let(:dossier) { procedure.dossiers.first }
      let(:commentaire) { create(:commentaire, dossier: dossier) }

      before do
        dossier.update(
          depose_at: Date.new(2024, 05, 23),
          state: "en_construction"
        )
        commentaire.piece_jointe.attach(
          io: File.open(file_path),
          filename: file_name,
          content_type: content_type,
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end

      subject(:process) { described_class.process(dossier) }

      context "when pj is a classical format image" do
        let(:file_path) { 'spec/fixtures/files/logo_test_procedure.png' }
        let(:file_name) { 'logo_test_procedure.png' }
        let(:content_type) { 'image/png' }

        it "creates a variant" do
          expect(commentaire.piece_jointe.first.variant(resize_to_limit: [400, 400]).key).to be_nil
          expect { subject }.to change { ActiveStorage::VariantRecord.count }.by(1)
          expect(commentaire.piece_jointe.first.variant(resize_to_limit: [400, 400]).key).not_to be_nil
          expect(commentaire.piece_jointe.first.variant(resize_to_limit: [2000, 2000]).key).to be_nil
        end
      end

      context "when pj is a rare format image" do
        let(:file_path) { 'spec/fixtures/files/pencil.tiff' }
        let(:file_name) { 'pencil.tiff' }
        let(:content_type) { 'image/tiff' }

        it "creates a variant" do
          expect(commentaire.piece_jointe.first.variant(resize_to_limit: [400, 400]).key).to be_nil
          expect { subject }.to change { ActiveStorage::VariantRecord.count }.by(2)
          expect(commentaire.piece_jointe.first.variant(resize_to_limit: [400, 400]).key).not_to be_nil
          expect(commentaire.piece_jointe.first.variant(resize_to_limit: [2000, 2000]).key).not_to be_nil
        end
      end
    end
  end
end
