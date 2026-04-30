# frozen_string_literal: true

class AddAdminDefaultPresentationToProcedures < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :procedures,
                  :admin_default_procedure_presentation,
                  foreign_key: false,
                  index: { algorithm: :concurrently, if_not_exists: true }

    add_column :procedures,
               :admin_default_procedure_presentation_active,
               :boolean,
               default: false,
               null: false
  end
end
