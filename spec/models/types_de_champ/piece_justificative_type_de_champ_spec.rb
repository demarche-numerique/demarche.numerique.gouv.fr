# frozen_string_literal: true

describe TypesDeChamp::PieceJustificativeTypeDeChamp do
  describe '#libelle_as_filename' do
    subject { build(:type_de_champ_piece_justificative, libelle:).libelle_as_filename }

    let(:libelle) { "  #/🐉 1 très  intéressant Bilan " }

    it { is_expected.to eq("1-tres-interessant-bilan") }
  end

  describe '#columns' do
    let(:procedure) { create(:procedure) }

    it 'adds RIB columns' do
      tdc = create(:type_de_champ_piece_justificative, procedure:, nature: 'rib')
      cols = tdc.columns(procedure_id: procedure.id, displayable: true)
      labels = cols.map(&:label)
      expect(labels.any? { _1.include?('Titulaire') }).to be true
      expect(labels.any? { _1.include?('IBAN') }).to be true
      expect(labels.any? { _1.include?('BIC') }).to be true
      expect(labels.any? { _1.include?('Nom de la Banque') }).to be true
    end

    it 'adds justificatif de domicile columns with i18n labels' do
      tdc = create(:type_de_champ_piece_justificative, procedure:, nature: 'justificatif_domicile')
      cols = tdc.columns(procedure_id: procedure.id, displayable: true)
      labels = cols.map(&:label)
      expect(labels.any? { _1.include?('Bénéficiaire') }).to be true
      expect(labels.any? { _1.include?('Adresse') }).to be true
      expect(labels.any? { _1.include?('Date d’émission') }).to be true
    end

    it 'adds avis impot columns with i18n labels' do
      tdc = create(:type_de_champ_piece_justificative, procedure:, nature: 'avis_impot')
      cols = tdc.columns(procedure_id: procedure.id, displayable: true)
      labels = cols.map(&:label)
      expect(labels.any? { _1.include?('Déclarant 1') }).to be true
      expect(labels.any? { _1.include?('Référence de l’avis') }).to be true
      expect(labels.any? { _1.include?('Revenu fiscal de référence') }).to be true
      expect(labels.any? { _1.include?('Date de mise en recouvrement') }).to be true
      expect(labels.any? { _1.include?('Commune') }).to be true
    end
  end

  describe '#champ_value_for_export' do
    context 'when nature is titre_identite' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:type_de_champ) { champ.type_de_champ }

      it 'returns "absent" when no file attached' do
        expect(type_de_champ.typed_champ_value_for_export(champ)).to eq('absent')
      end

      it 'returns "présent" when file attached' do
        champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
        expect(type_de_champ.typed_champ_value_for_export(champ)).to eq('présent')
      end
    end

    context 'when nature is not titre_identite' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      let(:type_de_champ) { champ.type_de_champ }

      it 'returns filenames' do
        champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
        expect(type_de_champ.typed_champ_value_for_export(champ)).to include('logo_test_procedure.png')
      end

      it 'returns empty string when no file' do
        expect(type_de_champ.typed_champ_value_for_export(champ)).to eq('')
      end
    end
  end

  describe '#champ_value_for_api' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }

    before { allow(ClamavService).to receive(:safe_file?).and_return(true) }

    it 'returns url for first file in v1 when safe' do
      champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
      champ.piece_justificative_file.first.blob.update(virus_scan_result: ActiveStorage::VirusScanner::SAFE)
      expect(champ.type_de_champ.typed_champ_value_for_api(champ, version: 1)).to include('/rails/active_storage/')
    end

    it 'returns nil when infected' do
      champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
      champ.piece_justificative_file.first.blob.update(virus_scan_result: ActiveStorage::VirusScanner::INFECTED)
      expect(champ.type_de_champ.typed_champ_value_for_api(champ, version: 1)).to be_nil
    end
  end

  describe '#allowed_content_types' do
    it 'returns jpeg/png for titre_identite' do
      tdc = create(:type_de_champ_piece_justificative, nature: 'titre_identite')
      expect(tdc.allowed_content_types).to match_array(['image/jpeg', 'image/png'])
    end

    ['rib', 'justificatif_domicile', 'avis_impot'].each do |ocr_nature|
      it "restricts to doc and image types for #{ocr_nature}" do
        tdc = create(:type_de_champ_piece_justificative, nature: ocr_nature)
        expect(tdc.allowed_content_types).to include('application/pdf')
        expect(tdc.allowed_content_types).to include('image/jpeg')
        expect(tdc.allowed_content_types).not_to include('application/zip')
      end
    end

    it 'restricts to selected families when pj_limit_formats enabled' do
      tdc = create(:type_de_champ_piece_justificative, pj_limit_formats: '1', pj_format_families: ['document_texte'])
      expect(tdc.allowed_content_types).to include('application/pdf')
      expect(tdc.allowed_content_types).not_to include('application/zip')
    end

    it 'does not restrict when pj_limit_formats enabled but families empty' do
      tdc = create(:type_de_champ_piece_justificative, pj_limit_formats: '1', pj_format_families: [])
      expect(tdc.allowed_content_types).to include('application/pdf')
      expect(tdc.allowed_content_types).to include('application/zip')
    end
  end

  describe '#max_file_size_bytes' do
    it 'is 20MB for titre_identite' do
      tdc = create(:type_de_champ_piece_justificative, nature: 'titre_identite')
      expect(tdc.max_file_size_bytes).to eq(20.megabytes)
    end

    it 'is 200MB by default' do
      tdc = create(:type_de_champ_piece_justificative)
      expect(tdc.max_file_size_bytes).to eq(200.megabytes)
    end
  end
end
