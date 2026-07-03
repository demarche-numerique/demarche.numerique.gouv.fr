# frozen_string_literal: true

class Champs::SiretChamp < ChampData
  include Dry::Monads[:result]
  validate :validate_etablissement, if: :should_validate_in_current_context?
  normalizes :external_id, with: -> siret { siret.gsub(/[[:space:]]/, "") }

  def has_async_external_data?
    true
  end

  def focusable_input_id(attribute = :value)
    [input_id, :value].compact.join('-')
  end

  def error_id(attribute = :value)
    [html_id, 'error_id', :value].compact.join('-')
  end

  # TODO: remove after T20251029backfillChampSiretExternalStateTask
  def external_id
    idle? && etablissement_id.present? ? value : super
  end

  def after_reset_external_data(opts = {})
    old_etablissement = etablissement
    super(etablissement_id: nil, prefilled: false, value: nil)
    old_etablissement&.destroy
  end

  def ready_for_external_call?
    Siret.new(siret: external_id).valid?
  end

  def fetch_external_data
    case APIEntrepriseService.create_etablissement_with_fallback(self, external_id.delete(" "), dossier.user&.id)
    in Success(etablissement) if etablissement.as_degraded_mode?
      Failure(retryable: true, error: StandardError.new("API Entreprise: degraded mode"), code: 503)
    in Success(etablissement)
      Success(etablissement:, value: external_id)
    in Failure(type: :not_found, **)
      Failure(retryable: false, error: StandardError.new('NotFound'), code: 404)
    in Failure(type:, code:, retryable:, **)
      Failure(retryable:, error: StandardError.new("API Entreprise: #{type}"), code:)
    end
  end

  def search_terms
    etablissement.present? ? etablissement.search_terms : [value]
  end

  def save_additional_job_exception(exception, code)
    exceptions = fetch_external_data_exceptions || []
    exceptions << ExternalDataException.new(error: exception.inspect, code:)
    update_columns(fetch_external_data_exceptions: exceptions)
  end

  private

  # We want to validate if SIRET really exists
  # It's valid when an etablissement have been created in turbo with SIRET controller
  # When API Entreprise is down, user won't be stuck because
  # SIRET controller creates an etablissement in degraded mode
  def validate_etablissement
    return if external_id.blank?
    return if etablissement.present?
    return if pending?

    validator = ActiveModel::Validations::SiretValidator.new(attributes: { value: true })

    # siret may have been formatted with spaces
    validator.validate_each(self, :external_id, external_id.gsub(/[[:space:]]/, ""))

    if errors.empty?
      errors.add(:external_id, :not_found)
    end
  end
end
