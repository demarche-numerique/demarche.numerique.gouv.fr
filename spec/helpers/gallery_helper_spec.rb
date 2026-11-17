# frozen_string_literal: true

RSpec.describe GalleryHelper, type: :helper do
  let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
  let(:public_type_de_champs) { [{ type: :piece_justificative, stable_id: 3, libelle: 'Justificatif de domicile' }] }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ_pj) { dossier.champ_data.first }

  let(:attachment) do
    champ_pj.piece_justificative_file.attach(
      io: file,
      filename: file.original_filename,
      content_type: file.content_type,
      metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
    )
    champ_pj.piece_justificative_file.attachments.first
  end

  describe ".record_libelle" do
    it "returns the champ libelle" do
      expect(helper.record_libelle(champ_pj)).to eq('Justificatif de domicile')
    end

    context "when the type_de_champ is no longer in the dossier revision" do
      it "falls back to a generic libelle instead of raising (RAILS-M73)" do
        fresh_champ = dossier.champ_data.find(champ_pj.id)
        allow(fresh_champ).to receive(:stable_id).and_return(-1)

        expect(helper.record_libelle(fresh_champ)).to eq('Pièce jointe')
      end
    end
  end

  describe ".image_variant_url_for" do
    subject { image_variant_url_for(attachment) }

    context "when image attachment has a variant", :external_deps do
      let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

      it "returns the variant URL when processed" do
        attachment.variant(resize_to_limit: [400, 400]).processed
        expect(subject).not_to eq("apercu-indisponible.png")
      end
    end

    context "when image attachment has no variant" do
      let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

      it "returns fallback image and doesn't create variant when not processed" do
        expect { subject }.not_to change { ActiveStorage::VariantRecord.count }
        expect(subject).to be_nil
      end
    end

    context "when attachment cannot be represented with a variant" do
      let(:file) { fixture_file_upload('spec/fixtures/files/instructeurs-file.csv', 'text/csv') }

      it "returns fallback image and doesn't create variant" do
        expect { subject }.not_to change { ActiveStorage::VariantRecord.count }
        expect(subject).to be_nil
      end
    end
  end

  describe ".pdf_preview_variant_url_for" do
    subject { pdf_preview_variant_url_for(attachment) }

    context "when pdf attachment has a preview with variant" do
      let(:file) { fixture_file_upload('spec/fixtures/files/RIB.pdf', 'application/pdf') }

      it "returns the variant URL of the preview (not the full-size preview)", :external_deps do
        attachment.preview(resize_to_limit: [400, 400]).processed
        preview_image = attachment.blob.preview_image
        variant = preview_image.variant(resize_to_limit: [400, 400]).processed

        freeze_time do
          expect(subject).to eq(variant.url)
          expect(subject).not_to eq(preview_image.url)
        end
      end
    end

    context "when pdf attachment has no preview" do
      let(:file) { fixture_file_upload('spec/fixtures/files/RIB.pdf', 'application/pdf') }

      it "returns fallback image and doesn't create preview when not processed" do
        expect { subject }.not_to change { ActiveStorage::VariantRecord.count }
        expect(subject).to be_nil
      end
    end

    context "when attachment cannot be represented with a preview" do
      let(:file) { fixture_file_upload('spec/fixtures/files/instructeurs-file.csv', 'text/csv') }

      it "returns fallback image and doesn't create preview" do
        expect { subject }.not_to change { ActiveStorage::VariantRecord.count }
        expect(subject).to be_nil
      end
    end
  end

  describe ".variant_url_for" do
    subject { variant_url_for(attachment) }

    context "when attachment is an image with no variant" do
      let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

      it { is_expected.to be_nil }
    end

    context "when attachment is a pdf with no preview" do
      let(:file) { fixture_file_upload('spec/fixtures/files/RIB.pdf', 'application/pdf') }

      it { is_expected.to be_nil }
    end
  end

  describe ".record_libelle" do
    subject { record_libelle(record) }

    context "when record is a Champ" do
      let(:record) { champ_pj }

      it { is_expected.to eq('Justificatif de domicile') }
    end

    context "when record is a Commentaire" do
      let(:record) { commentaires.from_usager }

      it { is_expected.to eq('Pièce jointe au message') }
    end

    context "when record is an Avis" do
      let(:record) { avis.pending }

      it { is_expected.to eq("Pièce jointe à l’avis") }
    end
  end
end
