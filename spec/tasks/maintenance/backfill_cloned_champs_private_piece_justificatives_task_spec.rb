# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe BackfillClonedChampsPrivatePieceJustificativesTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_private:) }
      let(:types_de_champ_private) { [{ type: :piece_justificative }, { type: :text }] }

      let(:parent_dossier) { create(:dossier, procedure:) }
      let(:cloned_dossier) { create(:dossier, procedure:) }

      let(:parent_champ_pj) { parent_dossier.root_private_champs.find(&:piece_justificative?) }
      let(:cloned_champ_pj) { cloned_dossier.root_private_champs.find(&:piece_justificative?) }

      before do
        cloned_dossier.update(parent_dossier:) # used on factorie, does not seed private_champs..
        parent_champ_pj.piece_justificative_file.attach(
          io: StringIO.new("x" * 2),
          filename: "me.jpg",
          content_type: "image/png",
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end

      subject { described_class.process(cloned_dossier) }

      context 'when dossier and parent have the same pjs' do
        it 'detaches sames blob between parent_dossier and dossier' do
          cloned_champ_pj.piece_justificative_file.attach(parent_champ_pj.piece_justificative_file.first.blob)

          subject
          expect(cloned_champ_pj.reload.piece_justificative_file.attached?).to be_falsey
        end
      end

      context 'when dossier and parent have different pjs' do
        it 'keeps different blobs between parent_dossier and dossier' do
          cloned_champ_pj.piece_justificative_file.attach(
            io: StringIO.new("x" * 2),
            filename: "me.jpg",
            content_type: "image/png",
            metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
          )

          described_class.process(cloned_dossier)
          subject
          expect(cloned_champ_pj.reload.piece_justificative_file.attached?).to be_truthy
        end
      end
    end
  end
end
