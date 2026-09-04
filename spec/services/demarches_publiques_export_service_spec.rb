# frozen_string_literal: true

describe DemarchesPubliquesExportService do
  let(:procedure) { create(:procedure, :published, :with_zone, :with_service, :with_type_de_champ, estimated_dossiers_count: 4) }
  let(:gzip_filename) { "demarches.json.gz" }

  after { FileUtils.rm(gzip_filename) }

  describe 'call' do
    it 'generate json for all closed procedures' do
      expected_result = {
        id: procedure.to_typed_id,
        number: procedure.id,
        title: procedure.libelle,
        description: "Demande de subvention à l’intention des associations",
        state: 'publiee',
        declarative: nil,
        forIndividual: false,
        service: {
          nom: procedure.service.nom,
          siret: procedure.service.siret,
          organisme: "organisme",
          typeOrganisme: "association",
          departement: nil,
        },
        cadreJuridiqueURL: "un cadre juridique important",
        demarcheURL: Rails.application.routes.url_helpers.commencer_url(path: procedure.path),
        dpoURL: nil,
        noticeURL: nil,
        siteWebURL: "https://mon-site.gouv",
        logo: nil,
        notice: nil,
        deliberation: nil,
        dateCreation: procedure.created_at.iso8601,
        datePublication: procedure.published_at.iso8601,
        dateDerniereModification: procedure.updated_at.iso8601,
        dateDepublication: nil,
        dateFermeture: nil,
        zones: ["Ministère 1"],
        tags: [],
        dossiersCount: 4,
        revision: {
          id: procedure.active_revision.to_typed_id,
          datePublication: procedure.active_revision.published_at.iso8601,
          champDescriptors: [
            {
              id: procedure.active_revision.public_root_type_de_champs.first.to_typed_id,
              description: procedure.active_revision.public_root_type_de_champs.first.description,
              label: procedure.active_revision.public_root_type_de_champs.first.libelle,
              required: true,
              __typename: "TextChampDescriptor",
            },
          ],
          annotationDescriptors: [],
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
  end

  def deflat_gzip(gzip_filename)
    Zlib::GzipReader.open(gzip_filename) do |gz|
      return gz.read
    end
  end
end
