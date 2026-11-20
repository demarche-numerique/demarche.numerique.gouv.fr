# frozen_string_literal: true

class Champs::DossierLinkChamp < ChampData
  # A linkable dossier, normalized from either a still-present Dossier or a purged
  # DeletedDossier. `id` is always the original dossier number (the option value).
  LinkableDossier = Data.define(:id, :procedure_id, :depose_on, :expired_on) do
    def expired? = expired_on.present?
  end

  DOSSIER_NUMBER_REGEXP = /\A\d+\z/

  # Checked before the lookups: they cast the value to an integer, so "12345 abc"
  # would match dossier 12345 while the whole string got stored.
  validates :value, format: { with: DOSSIER_NUMBER_REGEXP }, allow_blank: true, if: :should_validate_in_current_context?
  validates_with DossierLinkValidator, if: -> { should_validate_in_current_context? && dossier_number? }

  before_save :store_linked_dossier, if: :value_changed?

  def self.complete_linked_dossiers!(champs)
    incomplete = champs.filter(&:linked_dossier_incomplete?)

    return if incomplete.empty?

    value_jsons = linked_value_jsons(incomplete.map { it.value.to_i }.uniq)

    incomplete.group_by(&:value).each do |value, champs_with_value|
      value_json = value_jsons[value.to_i]
      group = champs_with_value.filter { it.value_json != value_json }

      next if value_json.blank? || group.empty?
      next if where(id: group.map(&:id), value:).update_all(value_json:) != group.size

      group.each do |champ|
        champ.value_json = value_json
        champ.clear_attribute_changes([:value_json])
      end
    end
  end

  def self.linked_value_jsons(dossier_ids)
    live = Dossier.joins(:revision).where(id: dossier_ids).pluck('dossiers.id', 'procedure_revisions.procedure_id', 'dossiers.depose_at')
    missing_ids = dossier_ids - live.map(&:first)
    deleted = missing_ids.empty? ? [] : DeletedDossier.where(dossier_id: missing_ids).pluck(:dossier_id, :procedure_id, :depose_at)

    (deleted + live).to_h do |dossier_id, procedure_id, depose_at|
      [dossier_id, { 'procedure_id' => procedure_id, 'submitted_on' => depose_at&.to_date&.iso8601 }.compact]
    end
  end

  def dossier_number? = value&.match?(DOSSIER_NUMBER_REGEXP)

  def linked_dossier_incomplete?
    dossier_number? && value_json.to_h.values_at('procedure_id', 'submitted_on').any?(&:nil?)
  end

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

  def store_linked_dossier
    self.value_json = dossier_number? ? self.class.linked_value_jsons([value.to_i])[value.to_i] : nil
  end

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
