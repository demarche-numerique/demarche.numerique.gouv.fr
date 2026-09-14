# frozen_string_literal: true

class Cron::RetryDegradedSiretChampJob < Cron::CronJob
  self.schedule_expression = "every 2 hours"

  # They all went degraded within the same outage: spread them out, the champ
  # queue has no rate limiter of its own.
  SPREAD_OVER = 20.minutes

  # An outage leaves far more degraded champs than one run can replay without
  # flooding the pool. What is left over waits for the next run.
  BATCH_SIZE = 2_000

  def perform(*args)
    return if !APIEntreprise::HealthChecker.provider_up?(:insee_sirene)
    return if APIEntreprise::RateLimiter.throttled?(APIEntreprise::API::DEFAULT_POOL)

    retryable_batch.find_each do |champ|
      champ.fix_degraded!(wait: rand(0..SPREAD_OVER)) if champ.may_fix_degraded?
    end
  end

  private

  def retryable_batch
    with_a_usable_token(degraded_siret_champs)
      .limit(BATCH_SIZE)
      .preload(dossier: :procedure)
  end

  def degraded_siret_champs
    Champs::SiretChamp
      .degraded
      .joins(dossier: :procedure)
      .merge(Procedure.kept)
      .where.not("champs.stream LIKE ?", "#{Dossier::HISTORY_STREAM}%")
      .where(dossiers: { hidden_by_user_at: nil, hidden_by_administration_at: nil, hidden_by_expired_at: nil })
  end

  # Whatever blocks the token blocks every retry it covers, so it is filtered
  # here rather than discovered champ by champ once the batch is already full.
  def with_a_usable_token(champs)
    champs = champs
      .where(procedures: { api_entreprise_token_rejected_at: [nil, ..Procedure::TOKEN_REJECTION_HOLDS_FOR.ago] })
      .where.not(procedures: { id: procedures_with_an_unusable_token })

    return champs if Procedure.instance_api_entreprise_token.usable?

    champs.where.not(procedures: { api_entreprise_token: nil })
  end

  # No SQL predicate decodes a JWT, so this one check stays in Ruby — over the
  # procedures carrying a token of their own, not over the degraded backlog.
  def procedures_with_an_unusable_token
    Procedure
      .where.not(api_entreprise_token: nil)
      .pluck(:id, :api_entreprise_token)
      .filter_map { |id, token| id if !APIEntrepriseToken.new(token).usable? }
  end
end
