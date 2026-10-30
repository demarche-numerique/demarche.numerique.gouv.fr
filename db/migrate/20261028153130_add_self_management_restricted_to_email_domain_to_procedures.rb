# frozen_string_literal: true

class AddSelfManagementRestrictedToEmailDomainToProcedures < ActiveRecord::Migration[8.1]
  def change
    add_column :procedures, :self_management_restricted_to_email_domain, :boolean, default: true, null: false
  end
end
