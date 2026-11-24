# frozen_string_literal: true

module Maintenance
  # Recopie champs.id dans la colonne fantôme new_id pour préparer la bascule en
  # bigint. Les champs créés depuis le trigger champs_mirror_new_id sont déjà
  # remplis : il ne reste que le stock antérieur.
  #
  # La table champs est volumineuse et les lignes à remplir y sont majoritaires :
  # on parcourt toute la table par plages de clé primaire et on filtre dans
  # l'UPDATE de chaque lot, calculé entièrement en SQL (cf.
  # T20260805BackfillChampsValueUpdatedAtFromCheckpointTask).
  class BackfillChampsNewIdTask < MaintenanceTasks::Task
    BATCH_SIZE = 10_000

    throttle_on(backoff: 1.minute) do
      Sidekiq::Queue.new("default").size > 100 || Sidekiq::Queue.new("low").size > 1_000
    end

    def collection
      ChampData.in_batches(of: BATCH_SIZE)
    end

    def process(batch)
      # ignored_columns retire new_id de l'attribut, pas de la requête. Le garde
      # IS NULL rend chaque lot rejouable sans réécrire les lignes déjà remplies.
      batch.where(new_id: nil).update_all('new_id = id')
    end

    def count
      # la table champs est volumineuse, le COUNT déclenche des PG statement timeout
    end
  end
end
