# frozen_string_literal: true

class APIEntreprise::Status
  STATUS_PAGE_URL = "https://status.entreprise.api.gouv.fr"

  PROVIDER_LABELS = {
    insee_sirene: "Sirene (INSEE)",
    infogreffe_rcs: "Extrait Kbis (Infogreffe)",
    dgfip_numero_tva: "Numéro de TVA (DGFIP)",
    djepva_association: "Associations (DJEPVA)",
    dgfip_chiffre_affaires: "Chiffre d'affaires (DGFIP)",
    dgfip_attestation_fiscale: "Attestation fiscale (DGFIP)",
    gip_mds_effectifs: "Effectifs (GIP-MDS)",
    urssaf_attestation_sociale: "Attestation sociale (URSSAF)",
    banque_de_france_bilans: "Bilans (Banque de France)",
  }.freeze

  Provider = Data.define(:label, :ping_key, :raw_status, :checked_at) do
    def state
      return :unknown if raw_status.nil?

      raw_status.in?(APIEntreprise::HealthChecker::UP_STATUSES) ? :up : :down
    end
  end

  Pending = Data.define(:count, :oldest_at)
  ParkedJob = Data.define(:job, :count, :count_by_code, :retried_daily, :oldest_at)
  Pool = Data.define(:size, :remaining)

  def providers
    @providers ||= APIEntreprise::HealthChecker::PROVIDERS.map do |name, ping_key|
      Provider.new(label: PROVIDER_LABELS.fetch(name), ping_key:,
        raw_status: APIEntreprise::HealthChecker.cached_status(ping_key), checked_at: checked_at(ping_key))
    end
  end

  def down_providers = providers.filter { it.state == :down }

  def unknown_providers = providers.filter { it.state == :unknown }

  def pending
    parked = ParkedAPIEntrepriseFetch
      .where(job: APIEntreprise::Job::PING_KEY_BY_JOB.keys, daily_failures: nil)
      .joins(:procedure)
      .merge(Procedure.with_usable_api_entreprise_token)
    count, oldest_at = parked.pick(Arel.star.count, ParkedAPIEntrepriseFetch.arel_table[:created_at].minimum)

    Pending.new(count:, oldest_at: oldest_at&.in_time_zone) if count.positive?
  end

  def parked_by_job
    ParkedAPIEntrepriseFetch.group(:job, :code)
      .pluck(:job, :code, Arel.star.count, Arel.sql("COUNT(*) FILTER (WHERE daily_failures IS NOT NULL)"), Arel.sql("MIN(created_at)"))
      .group_by(&:first)
      .map do |job, rows|
        ParkedJob.new(job:, count: rows.sum { it[2] }, count_by_code: rows.to_h { [it[1], it[2]] },
          retried_daily: rows.sum { it[3] }, oldest_at: rows.map(&:last).min.in_time_zone)
      end
      .sort_by { -it.count }
  end

  def pools
    [*APIEntreprise::Job::POOL_BY_JOB.values, APIEntreprise::API::DEFAULT_POOL].uniq.sort.reverse
      .map { Pool.new(size: it, remaining: APIEntreprise::RateLimiter.remaining(it)) }
  end

  def token = Procedure.instance_api_entreprise_token

  private

  # The health check writes each status with CACHE_TTL: what is left of it
  # tells when it ran.
  def checked_at(ping_key)
    ttl = Kredis.redis.ttl(APIEntreprise::HealthChecker.cache_key(ping_key))
    (APIEntreprise::HealthChecker::CACHE_TTL - ttl.seconds).ago if ttl.positive?
  end
end
