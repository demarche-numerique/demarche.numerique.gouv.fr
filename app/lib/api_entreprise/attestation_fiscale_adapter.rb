# frozen_string_literal: true

class APIEntreprise::AttestationFiscaleAdapter < APIEntreprise::Adapter
  # Doc métier : https://entreprise.api.gouv.fr/catalogue/dgfip/attestations_fiscales
  # Swagger : https://entreprise.api.gouv.fr/developpeurs/openapi#tag/Attestations-sociales-et-fiscales/paths/~1v4~1dgfip~1unites_legales~1%7Bsiren%7D~1attestation_fiscale/get

  def initialize(siret, procedure_id, user_id)
    @siret = siret
    @procedure_id = procedure_id
    @user_id = user_id
  end

  private

  def get_resource
    api(@procedure_id).attestation_fiscale(siren, @user_id)
  end

  def process_params
    data = data_source[:data]

    Sentry.set_tags(siret: @siret)

    if data && data[:document_url].present?
      {
        entreprise_attestation_fiscale_url: data[:document_url],
      }
    else
      {}
    end
  end
end
