# frozen_string_literal: true

class Champs::DossierLinkChamp < Champ
  validate :value_integerable, if: -> { value.present? }, on: :prefill
  validate :dossier_exists, if: -> { should_validate_in_current_context? && value.present? }
  validate :dossier_in_allowed_procedures, if: -> { should_validate_in_current_context? && value.present? }

  private

  def dossier_exists
    linked_dossier = Dossier.find_by(id: value)
    if linked_dossier.nil? && !DeletedDossier.exists?(dossier_id: value)
      errors.add(:value, :not_found)
    elsif linked_dossier&.brouillon?
      errors.add(:value, :brouillon_not_allowed)
    end
  end

  def dossier_in_allowed_procedures
    return if errors.include?(:value) # dossier_exists already failed
    return if !type_de_champ.procedures_limit?

    allowed_ids = type_de_champ.dossier_link_procedure_ids
    return if allowed_ids.empty?

    dossier_matches = Dossier.joins(:revision).exists?(id: value, user: dossier.user, procedure_revisions: { procedure_id: allowed_ids })
    deleted_dossier_matches = DeletedDossier.exists?(dossier_id: value, user_id: dossier.user_id, procedure_id: allowed_ids)

    if !dossier_matches && !deleted_dossier_matches
      errors.add(:value, :not_in_allowed_procedures)
    end
  end

  def value_integerable
    Integer(value)
  rescue ArgumentError
    errors.add(:value, :not_integerable)
  end
end
