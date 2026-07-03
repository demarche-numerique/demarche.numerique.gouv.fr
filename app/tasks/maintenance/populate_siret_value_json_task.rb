# frozen_string_literal: true

# Dans le cadre de la story pour pouvoir rechercher un dossier en fonction des valeurs des champs branchées sur une API, voici une première pièce qui cible les champs RNA/RNF/SIRET (notamment les adresses pour de la recherche). Cette PR intègre :
#     la normalisation des adresses des champs RNA/RNF/SIRET
#     le fait de stocker ces données normalisées dans le champs.value_json (un jsonb)
#     le backfill les anciens champs RNA/RNF/SIRET
#     A (re)jouer après déploiement de PR #11013 https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/11013
module Maintenance
  class PopulateSiretValueJSONTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      ChampData.where(type: "Champs::SiretChamp").where.not(value: nil)
    end

    def process(champ)
      return if champ.etablissement.blank?
      champ.update!(value_json: champ.etablissement.champ_value_json)
    rescue ActiveRecord::RecordInvalid
      # noop, just a champ without dossier
    end

    def count
      # not really interested in counting because it raises PG Statement timeout
    end
  end
end
