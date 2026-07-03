# frozen_string_literal: true

class Migrations::BackfillStableIdJob < ApplicationJob
  queue_as :low

  DEFAULT_LIMIT = 50_000

  def perform(iteration, limit = DEFAULT_LIMIT)
    sql = "UPDATE champs SET stable_id = t.stable_id, stream = '#{Dossier::MAIN_STREAM}'
      FROM types_de_champ t
        WHERE champs.type_de_champ_id = t.id
        AND champs.id IN (SELECT id FROM champs WHERE champs.stable_id IS NULL LIMIT ?);"
    query = ActiveRecord::Base.sanitize_sql_array([sql, limit])
    ActiveRecord::Base.connection.execute(query)

    if ChampData.exists?(stable_id: nil)
      Migrations::BackfillStableIdJob.set(wait: 2.seconds).perform_later(iteration + 1, limit)
    end
  end
end
