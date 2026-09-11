# frozen_string_literal: true

class APIEntreprise::ExtraitKbisAdapter < APIEntreprise::Adapter
  # Doc métier : https://entreprise.api.gouv.fr/catalogue/infogreffe/rcs/extrait
  # Swagger : https://entreprise.api.gouv.fr/developpeurs/openapi#tag/Informations-generales/paths/~1v3~1infogreffe~1rcs~1unites_legales~1%7Bsiren%7D~1extrait_kbis/get

  private

  def get_resource
    api(@procedure_id).extrait_kbis(siren)
  end

  def process_params
    result = {}
    data = data_source[:data]

    Sentry.set_tags(siret: @siret)

    if data
      result[:entreprise_capital_social] = data[:capital][:montant] if data[:capital]
      result[:entreprise_nom_commercial] = data[:nom_commercial]
    end
    result
  end
end
