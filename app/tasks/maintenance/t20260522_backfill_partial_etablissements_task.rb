# frozen_string_literal: true

module Maintenance
  class T20260522BackfillPartialEtablissementsTask < MaintenanceTasks::Task
    # Re-fetch etablissements that have partial data due to 429s silently
    # swallowed as 404s in the pre-monads era (see PR #13101).
    # Uses entreprise_siren IS NULL as marker: any properly fetched
    # etablissement has entreprise_siren populated.

    include RunnableOnDeployConcern
    include Dry::Monads[:result]

    # Reserve quota for normal traffic — backfill pauses when < 200 remaining.
    # Jobs get the full 0-200 range, backfill only uses the 200+ surplus.
    BACKFILL_REMAINING_THRESHOLD = 200
    BACKFILL_POOL = APIEntreprise::API::DEFAULT_POOL # etablissement endpoint = pool 250

    throttle_on(backoff: 1.minute) do
      remaining = APIEntreprise::RateLimiter.remaining(BACKFILL_POOL)
      remaining.present? && remaining < BACKFILL_REMAINING_THRESHOLD
    end

    def collection
      Etablissement
        .where(entreprise_siren: nil)
        .where.not(siret: nil)
        .includes(dossier: :procedure, champ_data: { dossier: :procedure })
    end

    def process(etablissement)
      procedure_id = etablissement.dossier&.procedure&.id || etablissement.champ_data&.dossier&.procedure&.id
      return if procedure_id.nil?

      result = APIEntreprise::EtablissementAdapter.new(etablissement.siret, procedure_id).to_params

      case result
      in Success(params) if params.present?
        etablissement.update_columns(params)
      else
        nil
      end
    rescue => e
      Rails.logger.error("T20260522BackfillPartialEtablissementsTask: #{etablissement.id}: #{e.message}")
      Sentry.capture_exception(e, tags: { etablissement: etablissement.id })
    end

    def count
      collection.count
    end
  end
end
