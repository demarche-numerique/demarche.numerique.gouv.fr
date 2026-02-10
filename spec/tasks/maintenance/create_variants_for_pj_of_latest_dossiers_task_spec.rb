# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe CreateVariantsForPjOfLatestDossiersTask do
    describe "#process" do
      let(:procedure) { create(:procedure_with_dossiers, types_de_champ_public: [{ type: :piece_justificative, libelle: 'Justificatif de domicile', stable_id: 3 }]) }
      let(:dossier) { procedure.dossiers.first }
      let(:champ_pj) { dossier.champs.first }
      let(:attachment) { champ_pj.piece_justificative_file.attachments.first }
      let(:file_type) { '' }
      let(:task) { described_class.new.tap { _1.file_type = file_type } }

      before do
        champ_pj.piece_justificative_file.attach(file)

        dossier.update(
          depose_at: Date.new(2024, 05, 23),
          state: "en_construction"
        )
      end

      subject(:process) { task.process(dossier) }

      context "when pj is a classical format image" do
        let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

        it "enqueues a CreateVariantJob" do
          expect { subject }.to have_enqueued_job(CreateVariantJob).with(attachment.id, file_type: '')
        end

        context "when file_type is 'pdf'" do
          let(:file_type) { 'pdf' }

          it "enqueues a CreateVariantJob with the file_type" do
            expect { subject }.to have_enqueued_job(CreateVariantJob).with(attachment.id, file_type: 'pdf')
          end
        end
      end

      context "when pj is a pdf" do
        let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

        it "enqueues a CreateVariantJob" do
          expect { subject }.to have_enqueued_job(CreateVariantJob).with(attachment.id, file_type: '')
        end

        context "when file_type is 'image'" do
          let(:file_type) { 'image' }

          it "enqueues a CreateVariantJob with the file_type" do
            expect { subject }.to have_enqueued_job(CreateVariantJob).with(attachment.id, file_type: 'image')
          end
        end
      end
    end
  end
end
