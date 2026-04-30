# frozen_string_literal: true

describe ExportTemplate do
  let(:groupe_instructeur) { create(:groupe_instructeur, procedure:) }
  let(:export_template) { build(:export_template, groupe_instructeur:) }
  let(:procedure) { create(:procedure, types_de_champ_public:, for_individual:) }
  let(:for_individual) { false }
  let(:types_de_champ_public) do
    [
      { type: :piece_justificative, libelle: "Justificatif de domicile", mandatory: true, stable_id: 3 },
      { type: :piece_justificative, nature: 'titre_identite', libelle: "CNI", mandatory: true, stable_id: 5 },
    ]
  end

  describe '.default' do
    it 'set default values' do
      expect(export_template.export_pdf).to eq(ExportItem.default(prefix: "export", enabled: true))
      expect(export_template.dossier_folder).to eq(ExportItem.default(prefix: "dossier", enabled: true))
      expect(export_template.pjs).to eq([ExportItem.default(stable_id: 3, prefix: "justificatif-de-domicile", enabled: false)])
    end
  end

  describe '#pj' do
    context 'when pj exists' do
      subject { export_template.pj(double(stable_id: 3)) }

      it { is_expected.to eq(ExportItem.default(stable_id: 3, prefix: "justificatif-de-domicile", enabled: false)) }
    end

    context 'when pj does not exist' do
      subject { export_template.pj(TypeDeChamp.new(libelle: 'hi', stable_id: 10)) }

      it { is_expected.to eq(ExportItem.default(stable_id: 10, prefix: "hi", enabled: false)) }
    end
  end

  describe '#attachment_path' do
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    context 'for export pdf' do
      let(:export_template) do
        build(:export_template, groupe_instructeur:, dossier_folder: ExportItem.default(prefix: "DOSSIER"), export_pdf: ExportItem.default(prefix: "mon_export"))
      end

      let(:attachment) { ActiveStorage::Attachment.new(name: 'pdf_export_for_instructeur', blob: ActiveStorage::Blob.new(filename: "export.pdf")) }

      it 'gives absolute filename for export of specific dossier' do
        expect(export_template.attachment_path(dossier, attachment)).to eq("DOSSIER-#{dossier.id}/mon_export-#{dossier.id}.pdf")
      end

      context 'when export pdf is disabled' do
        let(:export_template) do
          build(:export_template, groupe_instructeur:, dossier_folder: ExportItem.default(prefix: "DOSSIER"), export_pdf: ExportItem.default(prefix: "mon_export", enabled: false))
        end

        it 'returns nil' do
          expect(export_template.attachment_path(dossier, attachment)).to be_nil
        end
      end
    end

    context 'for pj' do
      let(:champ_pj) { dossier.project_champs_public.first }
      let(:export_template) { create(:export_template, groupe_instructeur:, pjs: [ExportItem.default(stable_id: 3, prefix: "justif", enabled: true)]) }

      let(:attachment) { ActiveStorage::Attachment.new(name: 'pj', record: champ_pj, blob: ActiveStorage::Blob.new(filename: "superpj.png")) }

      it 'returns pj and custom name for pj' do
        expect(export_template.attachment_path(dossier, attachment, champ: champ_pj)).to eq("dossier-#{dossier.id}/justif-#{dossier.id}-01.png")
      end
    end

    context 'for attestation' do
      let!(:attestation) { create(:attestation, dossier:) }
      let(:attachment) { ActiveStorage::Attachment.new(name: 'Attestation', record: attestation, blob: ActiveStorage::Blob.new(filename: "attestation.pdf")) }

      it 'returns attestation and custom name for attestation' do
        expect(export_template.attachment_path(dossier, attachment)).to eq("dossier-#{dossier.id}/attestation-#{dossier.id}.pdf")
      end
    end

    context 'for commentaire attachment' do
      let(:commentaire) { create(:commentaire, :with_file, dossier: dossier) }
      let(:attachment) { commentaire.piece_jointe.first }
      let(:export_template) { build(:export_template, groupe_instructeur:, commentaires_attachments: true) }

      it 'returns commentaire attachment and its custom name' do
        expect(export_template.attachment_path(dossier, attachment)).to start_with("dossier-#{dossier.id}/messagerie/")
        expect(export_template.attachment_path(dossier, attachment)).to eq("dossier-#{dossier.id}/#{ActiveStorage::DownloadableFile.timestamped_filename(attachment)}")
      end
    end

    context 'for avis attachment' do
      let(:avis) { create(:avis, :with_introduction, dossier: dossier) }
      let(:attachment) { avis.introduction_file.attachment }
      let(:export_template) { build(:export_template, groupe_instructeur:, avis_attachments: true) }

      it 'returns avis attachment and its custom name' do
        expect(export_template.attachment_path(dossier, attachment)).to start_with("dossier-#{dossier.id}/avis/")
        expect(export_template.attachment_path(dossier, attachment)).to eq("dossier-#{dossier.id}/#{ActiveStorage::DownloadableFile.timestamped_filename(attachment)}")
      end
    end

    context 'for justificatif motivation' do
      let(:fake_justificatif) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
      let(:attachment) { dossier.justificatif_motivation.attachment }
      let(:export_template) { build(:export_template, groupe_instructeur:, justificatif_motivation: true) }

      before { dossier.update!(justificatif_motivation: fake_justificatif) }

      it 'returns justificatif motivation and its custom name' do
        expect(export_template.attachment_path(dossier, attachment)).to start_with("dossier-#{dossier.id}/dossier/")
        expect(export_template.attachment_path(dossier, attachment)).to eq("dossier-#{dossier.id}/#{ActiveStorage::DownloadableFile.timestamped_filename(attachment)}")
      end
    end
  end

  describe '#tags and #pj_tags' do
    let(:procedure) { build(:procedure, for_individual:) }

    context 'for entreprise procedure' do
      let(:for_individual) { false }
      let(:expected_tags) do
        [
          'entreprise_siren', 'entreprise_numero_tva_intracommunautaire', 'entreprise_siret_siege_social', 'entreprise_raison_sociale', 'entreprise_adresse',
          'dossier_depose_at', 'dossier_procedure_libelle', 'dossier_service_name', 'dossier_number', 'dossier_groupe_instructeur', 'dossier_last_champ_updated_at',
        ]
      end

      it do
        expect(export_template.tags.map { _1[:id] }).to match_array(expected_tags)
        expect(export_template.pj_tags.map { _1[:id] }).to match_array(expected_tags + ['original-filename'])
      end
    end

    context 'for individual procedure' do
      let(:for_individual) { true }
      let(:expected_tags) do
        [
          'individual_gender', 'individual_last_name', 'individual_first_name',
          'dossier_depose_at', 'dossier_procedure_libelle', 'dossier_service_name', 'dossier_number', 'dossier_groupe_instructeur', 'dossier_last_champ_updated_at',
        ]
      end

      it do
        expect(export_template.tags.map { _1[:id] }).to match_array(expected_tags)
        expect(export_template.pj_tags.map { _1[:id] }).to match_array(expected_tags + ['original-filename'])
      end
    end
  end
end
