# frozen_string_literal: true

module Maintenance
  class T20260623backfillRNAExternalStateTask < MaintenanceTasks::Task
    # Documentation: la refacto rna_use_external_champ_concern (#12725) a recopié value -> external_id
    # (t20260616) et re-rempli data/value_json (populate_rna_json_value), mais certaines valeurs n'ont pas été remplies
    # (api down / 404 ?) et aucune tâche n'a aligné external state
    # Tous les anciens champs RNA sont donc restés à `idle` (NULL) :
    #   - ceux qui ont déjà une data -> on les passe en `fetched`
    #   - ceux qui ont un external_id valide mais pas de data -> on relance le workflow async
    #     (fetch_later!) pour récupérer la donnée ou enregistrer une external_error propre.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    # on étale les fetch sur 2h pour ne pas saturer API Entreprise
    # on a ~ 12K champs concernés et uniquement 230 qui vont faire un appel api
    MAX_WAIT = 2.hours.to_i

    def collection
      # external_state idle est stocké à NULL ; sans external_id aucune des deux branches ne s'applique
      ChampData.where(type: "Champs::RNAChamp").where(external_state: nil).where.not(external_id: nil)
    end

    def process(champ)
      return unless champ.idle?

      if champ.data.present?
        champ.update_column(:external_state, 'fetched')
      elsif champ.may_fetch_later?
        champ.fetch_later!(wait: rand(0..MAX_WAIT))
      end
    end

    def count
      # la table champs est volumineuse, le COUNT déclenche des PG statement timeout
    end
  end
end
