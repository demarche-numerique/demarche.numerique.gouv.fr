# frozen_string_literal: true

class AddForeignKeyToAdminDefaultProcedurePresentationOnProcedures < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_foreign_key :procedures,
                    :procedure_presentations,
                    column: :admin_default_procedure_presentation_id,
                    validate: false

    validate_foreign_key :procedures, :procedure_presentations
  end
end
