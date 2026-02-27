# frozen_string_literal: true

class Champs::DgfipChamp < Champs::TextChamp
  # see https://github.com/betagouv/api-particulier/blob/master/src/presentation/middlewares/dgfip-input-validation.middleware.ts
  validates :numero_fiscal, format: { with: /\A\w{13,14}\z/ }, if: -> { validate_champ_value? && reference_avis.present? }
  validates :reference_avis, format: { with: /\A\w{13,14}\z/ }, if: -> { validate_champ_value? && numero_fiscal.present? }

  store :external_id, accessors: [:numero_fiscal, :reference_avis], coder: JSON

  def has_async_external_data?
    true
  end

  def fetch_external_data
    APIParticulier::DgfipAdapter.new(
      procedure.api_particulier_token,
      numero_fiscal,
      reference_avis,
      procedure.api_particulier_sources
    ).to_params
  end

  def ready_for_external_call?
    return false if numero_fiscal.nil? || reference_avis.nil?
    numero_fiscal.match?(/\A\w{13,14}\z/) && reference_avis.match?(/\A\w{13,14}\z/)
  end

  def numero_fiscal_input_id
    "#{input_id}-numero_fiscal"
  end

  def reference_avis_input_id
    "#{input_id}-reference_avis"
  end

  def focusable_input_id(attribute = :value)
    numero_fiscal_input_id
  end
end
