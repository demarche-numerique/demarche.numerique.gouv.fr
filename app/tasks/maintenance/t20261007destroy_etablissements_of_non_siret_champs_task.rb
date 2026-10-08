# frozen_string_literal: true

module Maintenance
  class T20261007destroyEtablissementsOfNonSiretChampsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      Etablissement.where(dossier_id: nil).in_batches(of: 10_000)
    end

    def process(batch)
      ChampData
        .where(etablissement_id: batch.select(:id))
        .where.not(type: 'Champs::SiretChamp')
        .find_each do |champ|
          etablissement_id = champ.etablissement_id

          ChampData.no_touching do
            champ.update_columns(etablissement_id: nil)
            Etablissement.find(etablissement_id).destroy
          end
        end
    end

    def count
    end
  end
end
