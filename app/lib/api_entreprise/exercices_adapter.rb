# frozen_string_literal: true

class APIEntreprise::ExercicesAdapter < APIEntreprise::Adapter
  # Doc métier : https://entreprise.api.gouv.fr/catalogue/dgfip/chiffres_affaires
  # Swagger : https://entreprise.api.gouv.fr/developpeurs/openapi#tag/Informations-financieres/paths/~1v3~1dgfip~1etablissements~1%7Bsiret%7D~1chiffres_affaires/get

  private

  def get_resource
    api(@procedure_id).exercices(@siret)
  end

  def process_params
    data = data_source[:data]
    Sentry.set_tags(siret: @siret)

    if data
      exercices_array = data.map do |exercice|
        {
          ca: exercice[:data][:chiffre_affaires].to_s,
          date_fin_exercice: Date.parse(exercice[:data][:date_fin_exercice]),
        }
      end

      if exercices_array.all? { |params| valid_params?(params) }
        { exercices_attributes: exercices_array }
      else
        {}
      end
    end
  end
end
