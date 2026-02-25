# frozen_string_literal: true

class Champs::DossierLinkChamp < Champ
  validate :value_integerable, if: -> { value.present? }, on: :prefill
  validate :dossier_exists, if: -> { validate_champ_value? && value.present? }

  def deleted_dossier
    return if value.blank?

    DeletedDossier.includes(:procedure).find_by(dossier_id: value)
  end

  private

  def dossier_exists
    if !Dossier.exists?(value) && !DeletedDossier.exists?(dossier_id: value)
      errors.add(:value, :not_found)
    end
  end

  def value_integerable
    Integer(value)
  rescue ArgumentError
    errors.add(:value, :not_integerable)
  end
end
