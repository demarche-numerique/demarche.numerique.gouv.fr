# frozen_string_literal: true

module Maintenance
  class T20251023MigrateChampsPaysAfterAPIGeoUpdateTask < MaintenanceTasks::Task
    # Documentation: cette tâche migre les valeurs des Champs::PaysChamp suite à la mise à jour
    # de la liste ISO 3166-1 dans APIGeoService. Deux types de modifications :
    # 1. DOM français (GP, MQ, GF, RE, YT) → France (FR)
    # 2. Mise à jour des libellés de pays (capitalisation des îles, simplification des noms officiels)
    # Cf https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12229

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    # Mapping: ancienne valeur => { new_value:, code: }
    COUNTRY_VALUE_MAPPING = {
      # DOM français → France
      "Guadeloupe" => { new_value: "France", code: "FR" },
      "Martinique" => { new_value: "France", code: "FR" },
      "Guyane française" => { new_value: "France", code: "FR" },
      "Réunion, Île de la" => { new_value: "France", code: "FR" },
      "Mayotte" => { new_value: "France", code: "FR" },

      # Mise à jour des libellés (capitalisation et simplification)
      "île Bouvet" => { new_value: "Île Bouvet", code: "BV" },
      "îles Cook" => { new_value: "Îles Cook", code: "CK" },
      "îles Féroé" => { new_value: "Îles Féroé", code: "FO" },
      "îles Heard-et-MacDonald" => { new_value: "Îles Heard-et-MacDonald", code: "HM" },
      "îles Caïmans" => { new_value: "Îles Caïmans", code: "KY" },
      "île Norfolk" => { new_value: "Île Norfolk", code: "NF" },
      "îles Turques-et-Caïques" => { new_value: "Îles Turques-et-Caïques", code: "TC" },
      "Iran, République islamique d'" => { new_value: "Iran", code: "IR" },
      "Corée, République populaire démocratique de" => { new_value: "Corée du Nord", code: "KP" },
      "Corée, République de" => { new_value: "Corée du Sud", code: "KR" },
      "Lao, République démocratique populaire" => { new_value: "Laos", code: "LA" },
      "Syrienne, République arabe" => { new_value: "Syrie", code: "SY" },
      "Îles Vierges des États-Unis" => { new_value: "Îles Vierges, États-Unis", code: "VI" },
    }.freeze

    def collection
      ChampData.where(type: "Champs::PaysChamp").select(:id, :value, :external_id)
    end

    def process(champ)
      mapping = COUNTRY_VALUE_MAPPING[champ.value]
      return if mapping.blank?

      champ.update_columns(
        value: mapping[:new_value],
        external_id: mapping[:code]
      )
    end

    def count
      with_statement_timeout("15min") do
        collection.count(:id)
      end
    end
  end
end
