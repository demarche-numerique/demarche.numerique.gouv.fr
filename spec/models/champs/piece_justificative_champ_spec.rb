# frozen_string_literal: true

require 'active_storage_validations/matchers'

describe Champs::PieceJustificativeChamp do
  include ActiveStorageValidations::Matchers

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.project_champs_public.first.writable! }

  describe "validations" do
    subject { champ }

    context "by default (public context)" do
      it "rejects file bigger than max size" do
        champ.piece_justificative_file.purge

        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('x'),
          filename: 'big.pdf',
          content_type: 'application/pdf'
        )
        blob.update_column(:byte_size, Champs::PieceJustificativeChamp::FILE_MAX_SIZE + 1)

        champ.piece_justificative_file.attach(blob)

        expect(champ.valid?(:champ_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end

      it "accepts a markdown file declared as the legacy text/x-markdown content type" do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('# titre'), filename: 'notes.md', content_type: 'text/x-markdown')

        expect(champ.valid?(:champ_value)).to be true
      end

      it "does not validate public PJ when validating private champs" do
        champ.piece_justificative_file = [
          {
            io: StringIO.new('x'),
            filename: 'bad.exe',
            content_type: 'application/x-ms-dos-executable',
          },
        ]

        expect(dossier.champs_public_valid?).to be false
        expect(dossier.champs_private_valid?).to be true
      end
    end

    context "when validation is disabled" do
      before { champ.type_de_champ.update(skip_pj_validation: true) }

      it "does not enforce file size on :champ_value" do
        champ.piece_justificative_file.purge
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('x'),
          filename: 'big.pdf',
          content_type: 'application/pdf'
        )
        blob.update_column(:byte_size, Champs::PieceJustificativeChamp::FILE_MAX_SIZE + 1)
        champ.piece_justificative_file.attach(blob)

        expect(champ.valid?(:champ_value)).to be true
      end
    end

    context "when content-type validation is disabled" do
      before { champ.type_de_champ.update(skip_content_type_pj_validation: true) }

      it "does not enforce content_type on :champ_value" do
        champ.piece_justificative_file.attach(
          io: StringIO.new('x'),
          filename: 'bad.exe',
          content_type: 'application/x-ms-dos-executable'
        )

        expect(champ.valid?(:champ_value)).to be true
      end
    end
  end

  describe 'dynamic validations' do
    context 'titre_identite nature' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.project_champs_public.first.writable! }

      it 'accepts jpeg under 20MB' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x' * 1024), filename: 'id.jpg', content_type: 'image/jpeg')
        expect(champ.valid?(:champ_value)).to be true
      end

      it 'rejects pdf' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'id.pdf', content_type: 'application/pdf')
        expect(champ.valid?(:champ_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end

      it 'rejects file bigger than 20MB' do
        champ.piece_justificative_file.purge
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('fichier_x'),
          filename: 'id.jpg',
          content_type: 'image/jpeg'
        )
        blob.update_column(:byte_size, 21.megabytes)
        champ.piece_justificative_file.attach(blob)
        expect(champ.valid?(:champ_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end
    end

    ['rib', 'justificatif_domicile', 'avis_impot'].each do |ocr_nature|
      context "#{ocr_nature} nature" do
        let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: ocr_nature }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:champ) { dossier.project_champs_public.first.writable! }

        it 'accepts pdf' do
          champ.piece_justificative_file.purge
          champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf')
          expect(champ.valid?(:champ_value)).to be true
        end

        it 'rejects zip' do
          champ.piece_justificative_file.purge
          champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'arc.zip', content_type: 'application/zip')
          expect(champ.valid?(:champ_value)).to be false
          expect(champ.errors[:piece_justificative_file]).to be_present
        end
      end
    end

    context 'pj_limit_formats with document_texte' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, pj_limit_formats: '1', pj_format_families: ['document_texte'] }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.project_champs_public.first.writable! }

      it 'accepts pdf' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf')
        expect(champ.valid?(:champ_value)).to be true
      end

      it 'rejects zip' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'arc.zip', content_type: 'application/zip')
        expect(champ.valid?(:champ_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end

      it 'accepts markdown declared as the legacy text/x-markdown content type' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('# titre'), filename: 'notes.md', content_type: 'text/x-markdown')
        expect(champ.valid?(:champ_value)).to be true
      end
    end

    context 'pj_limit_formats enabled with empty families' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, pj_limit_formats: '1', pj_format_families: [] }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.project_champs_public.first.writable! }

      it 'accepts pdf' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf')
        expect(champ.valid?(:champ_value)).to be true
      end

      it 'accepts zip' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'arc.zip', content_type: 'application/zip')
        expect(champ.valid?(:champ_value)).to be true
      end
    end
  end

  describe '#ocr_result' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'justificatif_domicile' }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.project_champs_public.first.writable! }

    context 'when not fetched' do
      before { allow(champ).to receive(:fetched?).and_return(false) }

      it { expect(champ.ocr_result).to be_nil }
    end

    context 'when fetched but value_json is nil' do
      before do
        allow(champ).to receive(:fetched?).and_return(true)
        allow(champ).to receive(:value_json).and_return(nil)
      end

      it { expect(champ.ocr_result).to be_nil }
    end

    context 'when fetched with value_json' do
      let(:value_json) { { 'beneficiary' => 'Jane Smith' } }

      before do
        allow(champ).to receive(:fetched?).and_return(true)
        allow(champ).to receive(:value_json).and_return(value_json)
      end

      it do
        expect(champ.ocr_result).to be_a(JustificatifDomicile)
        expect(champ.ocr_result.beneficiary).to eq('Jane Smith')
      end
    end

    context 'when nature is avis_impot' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'avis_impot' }]) }
      let(:value_json) { { 'reference_avis' => '2538A22409999' } }

      before do
        allow(champ).to receive(:fetched?).and_return(true)
        allow(champ).to receive(:value_json).and_return(value_json)
      end

      it do
        expect(champ.ocr_result).to be_a(AvisImpot)
        expect(champ.ocr_result.reference_avis).to eq('2538A22409999')
      end
    end
  end

  describe "#for_export" do
    subject { champ.type_de_champ.champ_value_for_export(champ) }

    it { is_expected.to eq('toto.txt') }

    context 'without attached file' do
      before { champ.piece_justificative_file.purge }
      it { is_expected.to eq(nil) }
    end
  end

  describe '#for_api' do
    before { champ.piece_justificative_file.first.blob.update(virus_scan_result:) }

    subject { champ.type_de_champ.champ_value_for_api(champ, version: 1) }

    context 'when file is safe' do
      let(:virus_scan_result) { ActiveStorage::VirusScanner::SAFE }
      it { is_expected.to include("/rails/active_storage/disk/") }
    end

    context 'when file is not scanned' do
      let(:virus_scan_result) { ActiveStorage::VirusScanner::PENDING }
      it { is_expected.to include("/rails/active_storage/disk/") }
    end

    context 'when file is infected' do
      let(:virus_scan_result) { ActiveStorage::VirusScanner::INFECTED }
      it { is_expected.to be_nil }
    end
  end
end
