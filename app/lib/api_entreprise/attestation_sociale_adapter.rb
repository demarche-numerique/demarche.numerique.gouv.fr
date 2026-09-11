# frozen_string_literal: true

class APIEntreprise::AttestationSocialeAdapter < APIEntreprise::Adapter
  # Doc métier : https://entreprise.api.gouv.fr/catalogue/urssaf/attestation_vigilance
  # Swagger : https://entreprise.api.gouv.fr/developpeurs/openapi#tag/Attestations-sociales-et-fiscales/paths/~1v4~1urssaf~1unites_legales~1%7Bsiren%7D~1attestation_vigilance/get

  def initialize(siret, procedure_id)
    @siret = siret
    @procedure_id = procedure_id
  end

  private

  def get_resource
    api(@procedure_id).attestation_sociale(siren)
  end

  def process_params
    data = data_source[:data]

    Sentry.set_tags(siret: @siret)

    if data && data[:document_url].present?
      {
        entreprise_attestation_sociale_url: data[:document_url],
      }
    else
      {}
    end
  end
end
