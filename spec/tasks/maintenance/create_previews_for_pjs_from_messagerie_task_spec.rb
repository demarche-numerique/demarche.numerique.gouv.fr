# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe CreatePreviewsForPjsFromMessagerieTask do
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

      context "when pj is a pdf" do
        let(:file_path) { 'spec/fixtures/files/RIB.pdf' }
        let(:file_name) { 'RIB.pdf' }
        let(:content_type) { 'application/pdf' }

        it "creates a preview", :external_deps do
          expect(commentaire.piece_jointe.first.preview(resize_to_limit: [400, 400]).image.attached?).to be false
          expect { subject }.to change { commentaire.piece_jointe.first.reload.preview(resize_to_limit: [400, 400]).image.attached? }
        end
      end
    end
  end
end
