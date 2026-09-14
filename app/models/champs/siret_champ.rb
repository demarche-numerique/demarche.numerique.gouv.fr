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

  def ready_for_external_retry? = procedure.api_entreprise_token_usable?

  def fetch_external_data
    if !procedure.api_entreprise_token_usable?
      # No call goes out, so the failure branch below would never alert.
      alert_global_token_refused(local_token_failure, 401) if !procedure.specific_api_entreprise_token?

      return degraded_failure(:token_rejected, 401)
    end

    case APIEntreprise::Sirene.fetch_etablissement(siret, procedure.id)
    in Success(etablissement)
      procedure.forget_api_entreprise_token_rejection!
      Success(etablissement:, value: siret)
    in Failure(type:, code:, **) if code.in?(ExternalDataException::DEFINITIVE_CODES)
      Failure(retryable: false, error: StandardError.new("API Entreprise: #{type}"), code:)
    in Failure(type:, code:, **)
      record_credentials_failure(type, code) if code.in?(ExternalDataException::CREDENTIALS_CODES)

      degraded_failure(type, code)
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

  # The administrateur can act on a token of their own; on the instance one,
  # only operations can — and only if we tell them.
  def record_credentials_failure(type, code)
    if procedure.specific_api_entreprise_token?
      procedure.mark_api_entreprise_token_as_rejected!
    else
      alert_global_token_refused(type, code)
    end
  end

  GLOBAL_TOKEN_ALERT_EVERY = 1.hour

  # Every dossier of every procedure hits the same wall: one alert per hour is
  # enough. The type says what to do — renew the key, fill the env var, or ask
  # for the missing scope.
  def alert_global_token_refused(type, code)
    key = "api_entreprise:global_token_refused:#{type}"
    return if !Rails.cache.write(key, true, expires_in: GLOBAL_TOKEN_ALERT_EVERY, unless_exist: true)

    Sentry.capture_message("global API Entreprise token is refused ! DO SOMETHING ! TTU !",
      level: :error, extra: { type:, code:, procedure_id: procedure.id })
  end

  # Same distinction as APIEntreprise::API makes, so the alert stays actionable.
  def local_token_failure
    procedure.api_entreprise_token.missing? ? :token_missing : :token_expired
  end

  def degraded_failure(type, code)
    Failure(degraded: true, value: siret, error: StandardError.new("API Entreprise: #{type}"), code:)
  end

  # Only a fetch brings an etablissement: the degraded branch carries the siret alone.
  def update_external_data!(hash)
    etablissement = hash[:etablissement]
    return super if etablissement.nil?

    super(hash.merge(value_json: etablissement.champ_value_json))
    APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedure.id, dossier.user&.id)
  end

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
