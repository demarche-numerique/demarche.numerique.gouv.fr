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

  def siret = external_id

  def after_reset_external_data(opts = {})
    old_etablissement = etablissement
    super(etablissement_id: nil, prefilled: false, value: nil)
    old_etablissement&.destroy
  end

  def ready_for_external_call?
    Siret.new(siret:).valid?
  end

  def ready_for_external_retry? = !procedure.api_entreprise_token_recently_rejected?

  def fetch_external_data
    return token_rejected_failure if procedure.api_entreprise_token_recently_rejected?

    case APIEntreprise::Sirene.fetch_etablissement(siret, procedure.id)
    in Success(etablissement)
      procedure.forget_api_entreprise_token_rejection!
      Success(etablissement:, value: siret)
    in Failure(type:, code:, **) if code.in?(ExternalDataException::DEFINITIVE_CODES)
      Failure(retryable: false, error: StandardError.new("API Entreprise: #{type}"), code:)
    in Failure(type:, code:, **)
      procedure.reject_api_entreprise_token! if token_rejected_by_api?(type, code)

      Failure(degraded: true, value: siret, error: StandardError.new("API Entreprise: #{type}"), code:)
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

  # token_missing and token_expired are decided before any call, and the
  # expiration alert already tells the administrateur about them.
  LOCAL_TOKEN_FAILURES = [:token_missing, :token_expired].freeze

  def token_rejected_by_api?(type, code)
    code.in?(ExternalDataException::CREDENTIALS_CODES) && !type.in?(LOCAL_TOKEN_FAILURES)
  end

  def token_rejected_failure
    Failure(degraded: true, value: siret,
      error: StandardError.new("API Entreprise: token rejected"), code: 401)
  end

  # Only a fetch brings an etablissement: the degraded branch carries the siret alone.
  def update_external_data!(hash)
    super
    return if !hash.key?(:etablissement)

    etablissement.update_champ_value_json!
    APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedure.id, dossier.user&.id)
  end

  # We want to validate if SIRET really exists
  # It's valid when an etablissement have been created in turbo with SIRET controller
  # When API Entreprise is down, user won't be stuck because
  # SIRET controller creates an etablissement in degraded mode
  def validate_etablissement
    return if siret.blank?
    return if etablissement.present?
    return if pending? || degraded?

    validator = ActiveModel::Validations::SiretValidator.new(attributes: { value: true })

    # siret may have been formatted with spaces
    validator.validate_each(self, :external_id, siret.gsub(/[[:space:]]/, ""))

    if errors.empty?
      errors.add(:external_id, :not_found)
    end
  end
end
