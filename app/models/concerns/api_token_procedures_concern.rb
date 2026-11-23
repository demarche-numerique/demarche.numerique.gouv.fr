# frozen_string_literal: true

module APITokenProceduresConcern
  extend ActiveSupport::Concern

  included do
    scope :following_clones_of, -> (procedure) do
      where(follows_clones: true).where('?::bigint = ANY(allowed_procedure_ids)', procedure.id)
    end

    scope :owned_by_an_administrator_of, -> (procedure) do
      where(administrateur_id: AdministrateursProcedure.where(procedure:).select(:administrateur_id))
    end
  end

  class_methods do
    def receive_clone(source:, clone:)
      following_clones_of(source)
        .owned_by_an_administrator_of(source)
        .owned_by_an_administrator_of(clone)
        .update_all(['allowed_procedure_ids = array_append(allowed_procedure_ids, ?::bigint)', clone.id])
    end
  end
end
