# frozen_string_literal: true

class APIEntrepriseService
  class << self
    include Dry::Monads[:result]

    # create etablissement with EtablissementAdapter
    # enqueue api_entreprise jobs to retrieve
    # all informations we can get about a SIRET.
    #
    # Returns Success(etablissement) on success
    # Returns Failure(type: :not_found, ...) if the SIRET is unknown
    # Returns Failure(type:, code:, retryable:, raw_response:) on API errors
    #
    def create_etablissement(dossier_or_champ, siret, user_id = nil)
      procedure_id = dossier_or_champ.procedure.id

      etablissement_result = APIEntreprise::EtablissementAdapter.new(siret, procedure_id).to_params
      return etablissement_result if etablissement_result.failure?

      etablissement_params = etablissement_result.value!
      return Failure(type: :not_found, code: 404, retryable: false, raw_response: nil) if etablissement_params.empty?

      etablissement = dossier_or_champ.build_etablissement(etablissement_params)
      etablissement.save!
      etablissement.update_champ_value_json!
      perform_later_fetch_jobs(etablissement, procedure_id, user_id)

      Success(etablissement)
    end

    def create_etablissement_as_degraded_mode(dossier_or_champ, siret, user_id = nil)
      etablissement = dossier_or_champ.build_etablissement(siret: siret)
      etablissement.save!

      procedure_id = dossier_or_champ.procedure.id

      perform_later_fetch_jobs(etablissement, procedure_id, user_id, wait: 30.minutes)

      etablissement
    end

    # Tries to create an etablissement; falls back to degraded mode if API is unavailable.
    #
    # Returns Success(etablissement) when the data is complete
    # Returns Failure(degraded: true, etablissement:, type:, code:) when only a
    #   stub could be built: the caller can carry on, a backfill completes it later
    # Returns Failure(type:, code:, retryable:, raw_response:) on a plain failure
    def create_etablissement_with_fallback(dossier_or_champ, siret, user_id = nil)
      case create_etablissement(dossier_or_champ, siret, user_id)
      in Success(etablissement) if etablissement.as_degraded_mode?
        Failure(degraded: true, etablissement:, type: :incomplete_payload, code: 200)
      in Success(etablissement)
        Success(etablissement)
      in Failure(type: :rate_limited => type, code:, **)
        degraded(dossier_or_champ, siret, user_id, type:, code:)
      in Failure(type:, code:, retryable: true, **) if !APIEntreprise::HealthChecker.provider_up?(:insee_sirene)
        degraded(dossier_or_champ, siret, user_id, type:, code:)
      in result
        result
      end
    end

    def update_etablissement_from_degraded_mode(etablissement, procedure_id)
      case APIEntreprise::EtablissementAdapter.new(etablissement.siret, procedure_id).to_params
      in Success(etablissement_params) if etablissement_params.present?
        etablissement.update!(etablissement_params)
        etablissement.update_champ_value_json!
        champ = etablissement.champ_data
        champ.external_data_fetched! if champ&.may_external_data_fetched?
        etablissement
      else
        nil
      end
    end

    def perform_later_fetch_jobs(etablissement, procedure_id, user_id, wait: nil)
      jobs = [
        APIEntreprise::ExtraitKbisJob, APIEntreprise::TvaJob,
        APIEntreprise::AssociationJob, APIEntreprise::ExercicesJob,
        APIEntreprise::EffectifsJob, APIEntreprise::EffectifsAnnuelsJob, APIEntreprise::AttestationSocialeJob,
        APIEntreprise::BilansBdfJob,
      ]
      if etablissement.as_degraded_mode?
        jobs << APIEntreprise::EtablissementJob
      end
      jobs.each do |job|
        job.set(wait:).perform_later(etablissement.id, procedure_id)
      end

      APIEntreprise::AttestationFiscaleJob.set(wait:).perform_later(etablissement.id, procedure_id, user_id)
    end

    def degraded(dossier_or_champ, siret, user_id, type:, code:)
      Failure(degraded: true, type:, code:,
        etablissement: create_etablissement_as_degraded_mode(dossier_or_champ, siret, user_id))
    end

    def report_error(failure, extra = {})
      Sentry.capture_message(
        "API Entreprise error: #{failure[:type]}",
        level: :error,
        extra: extra.merge(code: failure[:code], raw_body: failure[:raw_response]&.body&.truncate(1000))
      )
    end
  end
end
