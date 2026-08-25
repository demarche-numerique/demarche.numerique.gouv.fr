# frozen_string_literal: true

# Spike. The backfill would be a batched MaintenanceTasks task in production
# (277k+ rows per type on some types); done inline here to keep the example
# self-contained.
class AddTypeToTypesDeChamp < ActiveRecord::Migration[8.0]
  def up
    add_column :types_de_champ, :type, :string

    safety_assured do
      TypeDeChamp.type_champs.each_value do |type_champ|
        execute(<<~SQL.squish)
          UPDATE types_de_champ
          SET type = '#{TypeDeChamp.class_for(type_champ)}'
          WHERE type_champ = '#{type_champ}'
        SQL
      end
    end
  end

  def down
    remove_column :types_de_champ, :type
  end
end
