# frozen_string_literal: true

class Migrations::BackfillRowIdJob < ApplicationJob
  def perform(batch)
    batch.each do |(row_id, champ_ids)|
      ChampData.where(id: champ_ids).update_all(row_id:)
    end
  end
end
