# frozen_string_literal: true

module APITokenSharingConcern
  extend ActiveSupport::Concern

  EXPIRATION_CO_RECIPIENTS_MAX = 5

  included do
    scope :visible_to, -> (reader) do
      shared_procedure = AdministrateursProcedure
        .where(procedure_id: reader.procedure_ids_outside_support, manager: [false, nil])
        .where('administrateurs_procedures.administrateur_id = api_tokens.administrateur_id')
        .where('api_tokens.allowed_procedure_ids IS NULL OR administrateurs_procedures.procedure_id = ANY(api_tokens.allowed_procedure_ids)')

      authenticable.unexpired.where.not(administrateur: reader).where(shared_procedure.arel.exists)
    end

    scope :duplicable_by, -> (administrateur) { where(administrateur:).or(visible_to(administrateur)) }
  end

  def procedure_ids_shared_with(administrateur)
    procedure_ids.intersection(administrateur.procedure_ids_outside_support)
  end

  def expiration_co_recipients
    ids = procedure_ids_shared_with(administrateur)
    co_admin_ids = AdministrateursProcedure
      .where(procedure_id: ids, manager: [false, nil])
      .where.not(administrateur_id:)
      .select(:administrateur_id)
    holder_ids = APIToken.authenticable.unexpired
      .where(administrateur_id: co_admin_ids)
      .where('allowed_procedure_ids IS NULL OR allowed_procedure_ids && ARRAY[?]::bigint[]', ids)
      .distinct
      .pluck(:administrateur_id)

    Administrateur.where(id: co_admin_ids)
      .sort_by { [holder_ids.include?(it.id) ? 0 : 1, -it.user.last_sign_in_at.to_i] }
      .first(EXPIRATION_CO_RECIPIENTS_MAX)
  end
end
