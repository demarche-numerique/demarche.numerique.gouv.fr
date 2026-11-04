# frozen_string_literal: true

# First step of the champs.id int4 -> bigint migration: the shadow column that
# will eventually become the primary key. Nullable, no default and no index, so
# this is a catalog-only change — instant even on a billion rows.
class AddNewIdToChamps < ActiveRecord::Migration[8.1]
  def change
    add_column :champs, :new_id, :bigint
  end
end
