# frozen_string_literal: true

class APIEntreprise::EtablissementAdapter < APIEntreprise::Adapter
  # Doc Métier : https://entreprise.api.gouv.fr/catalogue/insee/etablissements
  # Swagger : https://entreprise.api.gouv.fr/developpeurs/openapi#tag/Informations-generales/paths/~1v4~1insee~1sirene~1etablissements~1%7Bsiret%7D/get

  private

  def get_resource
    api(@procedure_id).etablissement(@siret)
  end

  def process_params
    raw_data = data_source[:data]
    Sentry.with_scope do |scope|
      scope.set_tags(siret: @siret)
      scope.set_extras(source: raw_data)

      etablissement_params = APIEntreprise::EtablissementPayload.etablissement_params(raw_data, attr_to_fetch)
      return {} unless valid_params?(etablissement_params)

      enterprise_params = APIEntreprise::EtablissementPayload.enterprise_params(raw_data[:unite_legale])
      enterprise_params = {} unless valid_params?(enterprise_params)

      etablissement_params.merge(enterprise_params)
    end
  end

  def attr_to_fetch = APIEntreprise::EtablissementPayload::ATTR_TO_FETCH
end
