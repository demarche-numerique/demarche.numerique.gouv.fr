# frozen_string_literal: true

describe DemarchesPubliquesExportService do
  let(:procedure) { create(:procedure, :published, :with_zone, :with_service, :with_type_de_champ, estimated_dossiers_count: 4) }
  let(:gzip_filename) { "demarches.json.gz" }

  after { FileUtils.rm(gzip_filename) }

  describe 'call' do
    it 'generate json for all closed procedures' do
      expected_result = {
        number: procedure.id,
        title: procedure.libelle,
        description: "Demande de subvention à l’intention des associations",
        state: 'publiee',
        forIndividual: false,
        service: {
          nom: procedure.service.nom,
          organisme: "organisme",
          typeOrganisme: "association",
          departement: nil,
        },
        cadreJuridiqueUrl: "un cadre juridique important",
        demarcheUrl: Rails.application.routes.url_helpers.commencer_url(path: procedure.path),
        dpoUrl: nil,
        noticeUrl: nil,
        siteWebUrl: "https://mon-site.gouv",
        logo: nil,
        notice: nil,
        deliberation: nil,
        datePublication: procedure.published_at.iso8601,
        zones: ["Ministère 1"],
        tags: [],
        dossiersCount: 4,
        revision: {
          champDescriptors: [
            {
              description: procedure.active_revision.public_root_type_de_champs.first.description,
              label: procedure.active_revision.public_root_type_de_champs.first.libelle,
              required: true,
              __typename: "TextChampDescriptor",
            },
          ],
        },
      }
      DemarchesPubliquesExportService.new(gzip_filename).call

      expect(JSON.parse(deflat_gzip(gzip_filename))[0]
        .deep_symbolize_keys)
        .to eq(expected_result)
    end

    it 'raises exception when procedure with bad data' do
      procedure.libelle = nil
      procedure.save(validate: false)

      expect { DemarchesPubliquesExportService.new(gzip_filename).call }.to raise_error(DemarchesPubliquesExportService::Error)
    end

    # DemarcheDescriptor.revision is non-nullable, so one procedure without a published
    # revision used to raise InvalidNullError and take the whole export down with it.
    it 'skips a procedure without a published revision instead of aborting the export' do
      exported = procedure # the `let` is lazy: create it before the export runs
      orphan = create(:procedure, :published, :with_zone, :with_service, :with_type_de_champ, estimated_dossiers_count: 4)
      orphan.update_column(:published_revision_id, nil)

      DemarchesPubliquesExportService.new(gzip_filename).call

      numbers = JSON.parse(deflat_gzip(gzip_filename)).map { it['number'] }
      expect(numbers).to include(exported.id)
      expect(numbers).not_to include(orphan.id)
    end
  end

  def deflat_gzip(gzip_filename)
    Zlib::GzipReader.open(gzip_filename) do |gz|
      return gz.read
    end
  end
end
