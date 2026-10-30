# frozen_string_literal: true

class APIEntreprise::Job < ApplicationJob
  include Dry::Monads[:result]
  include APIEntrepriseExternalDataConcern

  queue_as :default

  use_sidekiq_retry(report_after_attempts: 8)

  # Rate limit pool per job class (matches API Entreprise pools).
  # Jobs not listed here default to DEFAULT_POOL (250).
  POOL_BY_JOB = {
    'AttestationFiscaleJob' => 5,
    'EffectifsJob' => 50,
    'EffectifsAnnuelsJob' => 50,
    'AttestationSocialeJob' => 100,
  }.freeze

  # Maps each job to its API Entreprise provider ping key.
  # Used by before_perform to skip jobs when provider is down.
  # See https://entreprise.api.gouv.fr/developpeurs#surveillance-etat-fournisseurs
  PING_KEY_BY_JOB = {
    'ExtraitKbisJob' => APIEntreprise::HealthChecker::PROVIDERS[:infogreffe_rcs],
    'TvaJob' => APIEntreprise::HealthChecker::PROVIDERS[:dgfip_numero_tva],
    'AssociationJob' => APIEntreprise::HealthChecker::PROVIDERS[:djepva_association],
    'ExercicesJob' => APIEntreprise::HealthChecker::PROVIDERS[:dgfip_chiffre_affaires],
    'EffectifsJob' => APIEntreprise::HealthChecker::PROVIDERS[:gip_mds_effectifs],
    'EffectifsAnnuelsJob' => APIEntreprise::HealthChecker::PROVIDERS[:gip_mds_effectifs],
    'AttestationSocialeJob' => APIEntreprise::HealthChecker::PROVIDERS[:urssaf_attestation_sociale],
    'AttestationFiscaleJob' => APIEntreprise::HealthChecker::PROVIDERS[:dgfip_attestation_fiscale],
    'BilansBdfJob' => APIEntreprise::HealthChecker::PROVIDERS[:banque_de_france_bilans],
  }.freeze

  # If by the time the job runs the Etablissement has been deleted, ignore the job
  discard_on ActiveRecord::RecordNotFound

  def log_job_exception(exception)
    if etablissement.present?
      if etablissement.dossier.present?
        etablissement.dossier.log_api_entreprise_job_exception(exception)
      elsif etablissement.champ_data.present?
        etablissement.champ_data.save_additional_job_exception(exception, :unkonwn)
      end
    end
  end

  attr_reader :etablissement

  def self.perform_later_or_park(*arguments, wait: nil)
    if provider_down?
      park(arguments, code: 503)
    else
      set(wait:).perform_later(*arguments)
    end
  end

  def self.park(arguments, code:, retried_daily: false)
    ParkedAPIEntrepriseFetch.park!(etablissement_id: arguments.first, job: name.demodulize, procedure_id: arguments.second, arguments:, code:, retried_daily:)
  end

  def self.provider_down?
    ping_key = PING_KEY_BY_JOB[name.demodulize]
    ping_key.present? && !APIEntreprise::HealthChecker.provider_up?(ping_key)
  end

  def find_etablissement(etablissement_id)
    @etablissement = Etablissement.find(etablissement_id)
  end

  def with_adapter(adapter)
    if !api_entreprise_token_usable?
      mark_parked_fetch_out_of_queue
      return
    end

    code = api_unavailable_code
    return park_fetch(code) if code

    case adapter.to_params
    in Success(params) if params.present?
      release_parked_fetch
      yield params
    in Success
      release_parked_fetch
    in Failure(type: :unavailable_for_entity | :unknown_provider_error, code:, **)
      retry_daily(code)
    in Failure(retryable: true, code:, **)
      park_fetch(code)
    in Failure(retryable: false, type:, code:, **)
      Rails.logger.info("APIEntreprise non-retryable failure: job=#{self.class.name.demodulize} etablissement=#{etablissement_id} type=#{type} code=#{code}")
      release_parked_fetch
    end
  rescue StandardError
    release_parked_fetch
    raise
  end

  # Pool derived from job class name via POOL_BY_JOB.
  def api_pool
    POOL_BY_JOB.fetch(self.class.name.demodulize, APIEntreprise::API::DEFAULT_POOL)
  end

  private

  def etablissement_id = arguments.first

  def procedure = @procedure ||= Procedure.find(arguments.second)

  def api_unavailable_code
    return 503 if self.class.provider_down?

    429 if APIEntreprise::RateLimiter.throttled?(api_pool)
  end

  def api_entreprise_token_usable?
    return true if procedure.api_entreprise_token_usable?

    alert_global_token_refused(procedure.api_entreprise_token.unusable_reason, 401) if !procedure.specific_api_entreprise_token?
    false
  end

  def park_fetch(code, retried_daily: false)
    self.class.park(arguments, code:, retried_daily:)
  end

  def retry_daily(code)
    if ParkedAPIEntrepriseFetch.exists?(etablissement_id:, job: self.class.name.demodulize, daily_failures: ParkedAPIEntrepriseFetch::DAILY_RETRIES..)
      Rails.logger.info("APIEntreprise daily retries exhausted: job=#{self.class.name.demodulize} etablissement=#{etablissement_id} code=#{code}")
      release_parked_fetch
    else
      park_fetch(code, retried_daily: true)
    end
  end

  def mark_parked_fetch_out_of_queue
    ParkedAPIEntrepriseFetch.where(etablissement_id:, job: self.class.name.demodulize).update_all(enqueued_at: nil)
  end

  def release_parked_fetch
    ParkedAPIEntrepriseFetch.release!(etablissement_id:, job: self.class.name.demodulize)
  end
end
