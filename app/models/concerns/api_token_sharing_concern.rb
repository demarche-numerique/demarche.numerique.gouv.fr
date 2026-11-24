# frozen_string_literal: true

module APITokenSharingConcern
  extend ActiveSupport::Concern

  included do
    scope :visible_to, -> (reader) do
      shared_procedure = AdministrateursProcedure.without_support
        .where(procedure_id: reader.procedure_ids_without_support)
        .where('administrateurs_procedures.administrateur_id = api_tokens.administrateur_id')
        .where('api_tokens.allowed_procedure_ids IS NULL OR administrateurs_procedures.procedure_id = ANY(api_tokens.allowed_procedure_ids)')

      authenticable.unexpired.where.not(administrateur: reader).where(shared_procedure.arel.exists)
    end

    scope :duplicable_by, -> (administrateur) { where(administrateur:).or(visible_to(administrateur)) }
  end
end
