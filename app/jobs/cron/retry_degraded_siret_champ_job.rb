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

    Dossier.no_touching do
      degraded_siret_champs.find_each do |champ|
        champ.fix_degraded!(wait: rand(0..SPREAD_OVER)) if champ.may_fix_degraded?
      end
    end
  end

  private

  def degraded_siret_champs
    Champs::SiretChamp
      .degraded
      .joins(:dossier)
      .where(stream: Dossier::MAIN_STREAM)
      .where(dossiers: { hidden_by_user_at: nil, hidden_by_administration_at: nil })
      .limit(BATCH_SIZE)
  end
end
