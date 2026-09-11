# frozen_string_literal: true

class APIEntreprise::TvaAdapter < APIEntreprise::Adapter
  # Doc métier : https://entreprise.api.gouv.fr/catalogue/dgfip/numero_tva
  # Swagger : https://entreprise.api.gouv.fr/developpeurs/openapi#tag/Informations-financieres/paths/~1v3~1dgfip~1unites_legales~1%7Bsiren%7D~1numero_tva/get

  private

  def get_resource
    api(@procedure_id).tva(siren)
  end

  def process_params
    Sentry.set_tags(siret: @siret)

    data = data_source[:data]

    result = {}
    if data
      result[:entreprise_numero_tva_intracommunautaire] = data[:numero_tva]
    end
    result
  end
end
