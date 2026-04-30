# frozen_string_literal: true

require 'active_storage_validations/matchers'

describe Champs::PieceJustificativeChamp do
  include ActiveStorageValidations::Matchers

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champs.first }

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

        expect(champ.valid?(:champs_public_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end

      it "does not validate public PJ when validating private context" do
        champ.piece_justificative_file.attach(
          io: StringIO.new('x'),
          filename: 'bad.exe',
          content_type: 'application/x-ms-dos-executable'
        )

        expect(champ.valid?(:champs_private_value)).to be true
      end
    end

    context "when validation is disabled" do
      before { champ.type_de_champ.update(skip_pj_validation: true) }

      it { is_expected.not_to validate_size_of(:piece_justificative_file).on(:champs_public_value).less_than(Champs::PieceJustificativeChamp::FILE_MAX_SIZE) }
    end

    context "when content-type validation is disabled" do
      before { champ.type_de_champ.update(skip_content_type_pj_validation: true) }

      it { is_expected.not_to validate_content_type_of(:piece_justificative_file).on(:champs_public_value).rejecting('application/x-ms-dos-executable') }
    end
  end

  describe 'dynamic validations' do
    context 'titre_identite nature' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'accepts jpeg under 20MB' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x' * 1024), filename: 'id.jpg', content_type: 'image/jpeg')
        expect(champ.valid?(:champs_public_value)).to be true
      end

      it 'rejects pdf' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'id.pdf', content_type: 'application/pdf')
        expect(champ.valid?(:champs_public_value)).to be false
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
        expect(champ.valid?(:champs_public_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end
    end

    context 'pj_limit_formats with document_texte' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, pj_limit_formats: '1', pj_format_families: ['document_texte'] }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'accepts pdf' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf')
        expect(champ.valid?(:champs_public_value)).to be true
      end

      it 'rejects zip' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'arc.zip', content_type: 'application/zip')
        expect(champ.valid?(:champs_public_value)).to be false
        expect(champ.errors[:piece_justificative_file]).to be_present
      end
    end

    context 'pj_limit_formats enabled with empty families' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, pj_limit_formats: '1', pj_format_families: [] }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'accepts pdf' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf')
        expect(champ.valid?(:champs_public_value)).to be true
      end

      it 'accepts zip' do
        champ.piece_justificative_file.purge
        champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'arc.zip', content_type: 'application/zip')
        expect(champ.valid?(:champs_public_value)).to be true
      end
    end
  end

  describe '#ocr_result' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'justificatif_domicile' }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.champs.first }

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
      let(:value_json) { { 'beneficiary' => 'Jane Smith', 'address' => '123 Main St' } }

      before do
        allow(champ).to receive(:fetched?).and_return(true)
        allow(champ).to receive(:value_json).and_return(value_json)
      end

      it do
        expect(champ.ocr_result).to be_a(JustificatifDomicile)
        expect(champ.ocr_result.beneficiary).to eq('Jane Smith')
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
