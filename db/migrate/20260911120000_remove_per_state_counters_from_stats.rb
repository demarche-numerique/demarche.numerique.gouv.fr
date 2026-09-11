# frozen_string_literal: true

class RemovePerStateCountersFromStats < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :stats, :dossiers_brouillon, :bigint, default: 0
      remove_column :stats, :dossiers_en_construction, :bigint, default: 0
      remove_column :stats, :dossiers_en_instruction, :bigint, default: 0
      remove_column :stats, :dossiers_termines, :bigint, default: 0
    end
  end
end
