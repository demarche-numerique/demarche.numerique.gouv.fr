# frozen_string_literal: true

class Champs::DossierLinkChamp < Champ
  validate :value_integerable, if: -> { value.present? }, on: :prefill
  validate :dossier_exists, if: -> { validate_champ_value? && value.present? }

  private

  def dossier_exists
    if !Dossier.exists?(value)
      errors.add(:value, :not_found)
    end
  end

  def value_integerable
    Integer(value)
  rescue ArgumentError
    errors.add(:value, :not_integerable)
  end
end
