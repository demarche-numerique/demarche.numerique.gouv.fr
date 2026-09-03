# frozen_string_literal: true

class Champs::DossierLinkChamp < ChampData
  # A linkable dossier, normalized from either a still-present Dossier or a purged
  # DeletedDossier. `id` is always the original dossier number (the option value).
  LinkableDossier = Data.define(:id, :procedure_id, :depose_on, :expired_on) do
    def expired? = expired_on.present?
  end

  validates_with DossierLinkValidator, if: -> { should_validate_in_current_context? && value.present? }

  # The (still existing) procedures the field is restricted to, in the admin-configured order.
  def linkable_procedures
    @linkable_procedures ||= begin
      ids = type_de_champ.dossier_link_procedure_ids
      Procedure.where(id: ids).index_by(&:id).values_at(*ids).compact
    end
  end

  # The user's submitted dossiers on those procedures, grouped by procedure (newest first).
  # We offer exactly what the user still sees in their own dossier list (Dossier.visible_by_user),
  # so dossiers they deleted themselves stay excluded. Expired dossiers are added back so the user
  # can still link to them, whether they are still soft-deleted (Dossier#hidden_by_expired_at) or
  # already purged (DeletedDossier, reason: :expired).
  # Cost is constant: two grouped queries, regardless of the number of procedures.
  def linkable_dossiers_by_procedure
    @linkable_dossiers_by_procedure ||= begin
      by_procedure = linkable_dossiers.group_by(&:procedure_id)
      linkable_procedures.index_with do |procedure|
        by_procedure.fetch(procedure.id, []).sort_by(&:depose_on).reverse
      end
    end
  end

  # Offer a select/combobox (rather than free input) only when the field is limited
  # to procedures AND the user actually has at least one dossier to pick. Otherwise we
  # keep free input so the user can still type a number (e.g. a since-deleted dossier).
  def selectable?
    type_de_champ.procedures_limit? && linkable_dossiers_by_procedure.values.any?(&:present?)
  end

  private

  def linkable_dossiers
    active_linkable_dossiers + deleted_linkable_dossiers
  end

  def linkable_procedure_ids
    linkable_procedures.map(&:id)
  end

  # Still-present dossiers (visible or soft-expired) across all allowed procedures, in one query.
  # Scoped through the owner's association so we can only ever reach this user's own dossiers.
  def active_linkable_dossiers
    dossier.user.dossiers
      .joins(:revision)
      .where(procedure_revisions: { procedure_id: linkable_procedure_ids })
      .merge(Dossier.visible_by_user.or(Dossier.hidden_by_expired))
      .where(state: Dossier::SOUMIS)
      .where.not(id: dossier_id)
      .pluck('procedure_revisions.procedure_id', 'dossiers.id', 'dossiers.depose_at', 'dossiers.hidden_by_expired_at')
      .map { |procedure_id, id, depose_at, expired_at| LinkableDossier.new(id:, procedure_id:, depose_on: depose_at.to_date, expired_on: expired_at&.to_date) }
  end

  # Purged dossiers removed for expiration across all allowed procedures, in one query.
  # Scoped through the owner's association so we can only ever reach this user's own dossiers.
  def deleted_linkable_dossiers
    dossier.user.deleted_dossiers
      .where(procedure_id: linkable_procedure_ids, reason: :expired)
      .where.not(dossier_id: dossier_id)
      .pluck(:procedure_id, :dossier_id, :depose_at, :deleted_at)
      .map { |procedure_id, id, depose_at, deleted_at| LinkableDossier.new(id:, procedure_id:, depose_on: depose_at, expired_on: deleted_at.to_date) }
  end
end
