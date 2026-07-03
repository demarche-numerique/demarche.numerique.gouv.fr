# frozen_string_literal: true

# Dans le cadre de la story pour pouvoir rechercher un dossier en fonction des valeurs des champs branchées sur une API, voici une première pièce qui cible les champs RNA/RNF/SIRET (notamment les adresses pour de la recherche). Cette PR intègre :
#     la normalisation des adresses des champs RNA/RNF/SIRET
#     le fait de stocker ces données normalisées dans le champs.value_json (un jsonb)
#     le backfill les anciens champs RNA/RNF/SIRET
module Maintenance
  class PopulateRNAJSONValueTask < MaintenanceTasks::Task
    include Dry::Monads[:result]

    def collection
      # on regarde value et non external_id car avant le refacto #12725, on stockait directement dans value
      ChampData.where(type: "Champs::RNAChamp").where.not(value: nil)
    end

    def process(champ_data)
      return if champ_data&.dossier&.procedure&.id.blank?
      champ = Champ.from_data(champ_data)
      return if champ.nil?

      result = champ.send(:fetch_external_data)
      case result
      in Success(data:, value_json:, value:)
        begin
          champ.send(:update_external_data!, { data:, value_json:, value: })
        rescue ActiveRecord::RecordInvalid
          # some champ might have dossier nil
        end
      else # fondation was removed, but we kept API data in data:, use it to restore stuff
        data = champ.data.with_indifferent_access
        value_json = champ.send(:extract_value_json, data:)
        champ.update(data:, value_json:)
      end
    rescue URI::InvalidURIError
      # some Champs::RNAChamp contain spaces which raise this error
    rescue ActiveRecord::RecordNotFound
      # some Champs::RNAChamp procedure had been soft deleted
    end

    def count
      # not really interested in counting because it raises PG Statement timeout
    end
  end
end
