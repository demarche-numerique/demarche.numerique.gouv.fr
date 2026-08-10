# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260728PurgeEmptyAttachmentsTask do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.root_public_champs.first }

    def attach_without_validation(blob)
      champ.piece_justificative_file = [blob]
      champ.save!(validate: false)
      champ.piece_justificative_file.attachments.last
    end

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      let(:empty_attachment) do
        attach_without_validation(
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new(''), filename: 'empty.pdf', content_type: 'application/pdf')
        )
      end

      let(:filled_attachment) do
        attach_without_validation(
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf')
        )
      end

      it "sélectionne les pièces vides" do
        expect(collection).to include(empty_attachment)
      end

      it "ignore les pièces non vides" do
        expect(collection).not_to include(filled_attachment)
      end

      it "ignore les variantes" do
        empty_attachment.update_column(:record_type, 'ActiveStorage::VariantRecord')

        expect(collection).not_to include(empty_attachment)
      end

      it "ignore les aperçus PDF" do
        empty_attachment.update_column(:name, 'preview_image')

        expect(collection).not_to include(empty_attachment)
      end
    end

    describe "#process" do
      let(:attachment) do
        attach_without_validation(
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new(''), filename: 'empty.pdf', content_type: 'application/pdf')
        )
      end

      it "purge la pièce vide" do
        perform_enqueued_jobs do
          described_class.process(attachment)
        end

        expect(champ.reload.piece_justificative_file).not_to be_attached
      end
    end
  end
end
