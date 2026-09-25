# frozen_string_literal: true

class RemoveSearchTermsTextFromDossiers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :dossiers, :search_terms, :string
      remove_column :dossiers, :private_search_terms, :string
    end
  end
end
