# frozen_string_literal: true

describe ProcedureArchiveService do
  include ZipHelpers

  let(:procedure) { create(:procedure, :published, administrateurs: [administrateur]) }
  let(:instructeur) { create(:instructeur) }
  let(:administrateur) { administrateurs(:default_admin) }
  let(:service) { ProcedureArchiveService.new(procedure) }
  let(:year) { 2020 }
  let(:month) { 3 }
  let(:date_month) { Date.strptime("#{year}-#{month}", "%Y-%m") }
  let(:groupe_instructeurs) { instructeur.groupe_instructeurs }

  before do
    procedure.defaut_groupe_instructeur.add(instructeur)
  end

  describe '#make_and_upload_archive' do
    let!(:dossier) { create_dossier_for_month(year, month) }
    let!(:dossier_2020) { create_dossier_for_month(2020, month) }

    context 'for a specific month' do
      let(:archive) { create(:archive, user_profile: administrateur, time_span_type: 'monthly', job_status: 'pending', month: date_month, groupe_instructeurs: groupe_instructeurs) }
      let(:year) { 2021 }

      it 'collects files with success' do
        allow_any_instance_of(ActiveStorage::Attachment).to receive(:url).and_return("https://opengraph.githubassets.com/d0e7862b24d8026a3c03516d865b28151eb3859029c6c6c2e86605891fbdcd7a/socketry/async-io")

        VCR.use_cassette('archive/new_file_to_get_200') do
          service.make_and_upload_archive(archive)
        end

        archive.file.open do |f|
          structure = [
            "export/",
            "export/dossier-#{dossier.id}/",
            "export/dossier-#{dossier.id}/pieces_justificatives/",
            "export/dossier-#{dossier.id}/pieces_justificatives/attestation-dossier-#{dossier.id}-05-03-2021-00-00-#{dossier.attestation.pdf.id % 10000}.pdf",
            "export/dossier-#{dossier.id}/export-#{dossier.id}-05-03-2021-00-00-#{dossier.id % 10000}.pdf",
          ]
          expect(read_zip_entries(f.path)).to match_array(structure)
        end
        expect(archive.file.attached?).to be_truthy
      end

      it 'retry errors files with errors' do
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:url).and_return("https://www.demarches-simplifiees.fr/error_1")

        VCR.use_cassette('archive/new_file_to_get_400.html') do
          service.make_and_upload_archive(archive)
        end
        archive.file.open do |f|
          structure = [
            "export/",
            "export/-LISTE-DES-FICHIERS-EN-ERREURS.txt",
            "export/dossier-#{dossier.id}/",
            "export/dossier-#{dossier.id}/pieces_justificatives/",
            "export/dossier-#{dossier.id}/export-#{dossier.id}-05-03-2021-00-00-#{dossier.id % 10000}.pdf",
          ]
          expect(read_zip_entries(f.path)).to match_array(structure)
        end
        expect(archive.file.attached?).to be_truthy
      end

      context 'with a missing file' do
        let(:pj) do
          ActiveStorage::FakeAttachment.new(
            file: StringIO.new('coucou'),
            filename: "export-dossier.pdf",
            name: 'pdf_export_for_instructeur',
            id: 1,
            created_at: Time.zone.now
          )
        end

        let(:bad_pj) do
          ActiveStorage::FakeAttachment.new(
            file: nil,
            filename: "cni.png",
            name: 'cni.png',
            id: 2,
            created_at: Time.zone.now
          )
        end

        let(:documents) { [pj, bad_pj].map { |p| ActiveStorage::DownloadableFile.pj_and_path(dossier.id, p) } }
        before do
          allow_any_instance_of(PiecesJustificativesService).to receive(:liste_documents).and_return(documents)
        end

        it 'collect files without raising exception' do
          expect { service.make_and_upload_archive(archive) }.not_to raise_exception
        end

        it 'add bug report to archive' do
          service.make_and_upload_archive(archive)

          archive.file.open do |f|
            structure = [
              "export/",
              "export/-LISTE-DES-FICHIERS-EN-ERREURS.txt",
              "export/dossier-#{dossier.id}/",
              "export/dossier-#{dossier.id}/export-dossier-05-03-2020-00-00-1.pdf",
              "export/dossier-#{dossier.id}/pieces_justificatives/",
              "export/dossier-#{dossier.id}/export-#{dossier.id}-05-03-2021-00-00-#{dossier.id % 10000}.pdf",
            ]
            expect(read_zip_entries(f.path)).to match_array(structure)

            error_file_path = "export/-LISTE-DES-FICHIERS-EN-ERREURS.txt"
            content = read_zip_file_content(f.path, error_file_path)
            expect(content).to match(/Impossible de .* .*cni.*png/)
          end
        end
      end
    end

    context 'for all months' do
      let(:archive) { create(:archive, user_profile: administrateur, time_span_type: 'everything', job_status: 'pending', groupe_instructeurs: groupe_instructeurs) }

      it 'collect files' do
        allow_any_instance_of(ActiveStorage::Attachment).to receive(:url).and_return("https://opengraph.githubassets.com/5e61989aecb78e369c93674f877d7bf4ecde378850114a9563cdf8b6a2472536/typhoeus/typhoeus/issues/110")

        VCR.use_cassette('archive/old_file_to_get_200') do
          service.make_and_upload_archive(archive)
        end

        archive = Archive.last
        archive.file.open do |f|
          structure = [
            "export/",
            "export/dossier-#{dossier.id}/",
            "export/dossier-#{dossier.id}/pieces_justificatives/",
            "export/dossier-#{dossier.id}/pieces_justificatives/attestation-dossier-#{dossier.id}-05-03-2020-00-00-#{dossier.attestation.pdf.id % 10000}.pdf",
            "export/dossier-#{dossier.id}/export-#{dossier.id}-05-03-2020-00-00-#{dossier.id % 10000}.pdf",
            "export/dossier-#{dossier_2020.id}/",
            "export/dossier-#{dossier_2020.id}/export-#{dossier_2020.id}-05-03-2020-00-00-#{dossier_2020.id % 10000}.pdf",
            "export/dossier-#{dossier_2020.id}/pieces_justificatives/",
            "export/dossier-#{dossier_2020.id}/pieces_justificatives/attestation-dossier-#{dossier_2020.id}-05-03-2020-00-00-#{dossier_2020.attestation.pdf.id % 10000}.pdf",
          ]
          expect(read_zip_entries(f.path)).to match_array(structure)
        end
        expect(archive.file.attached?).to be_truthy
      end
    end
  end

  private

  def create_dossier_for_month(year, month)
    travel_to(Time.zone.local(year, month, 5))
    create(:dossier, :accepte, :with_attestation_acceptation, procedure: procedure)
  end
end
