# frozen_string_literal: true

RSpec.describe APIEntreprise::Status do
  subject(:status) { described_class.new }

  around do |example|
    clear_health_checks
    example.run
    clear_health_checks
  end

  def clear_health_checks
    APIEntreprise::HealthChecker::PROVIDERS.each_value do |key|
      Kredis.redis.del(APIEntreprise::HealthChecker.cache_key(key))
    end
  end

  def cache_status(ping_key, status, ttl: 300)
    Kredis.redis.set(APIEntreprise::HealthChecker.cache_key(ping_key), status, ex: ttl)
  end

  def provider(ping_key) = status.providers.find { it.ping_key == ping_key }

  describe '#providers' do
    it 'reads the state of each provider from the health-check cache' do
      cache_status('insee/sirene', 'ok')
      cache_status('banque_de_france/bilans', 'bad_gateway')

      expect(provider('insee/sirene').state).to eq(:up)
      expect(provider('banque_de_france/bilans')).to have_attributes(state: :down, raw_status: 'bad_gateway')
      expect(provider('infogreffe/rcs').state).to eq(:unknown)
      expect(status.down_providers.map(&:ping_key)).to eq(['banque_de_france/bilans'])
    end

    it 'dates the last check from what is left of the cache lifetime' do
      freeze_time
      cache_status('insee/sirene', 'ok', ttl: 180)

      expect(provider('insee/sirene').checked_at).to eq(2.minutes.ago)
    end
  end

  describe '#degraded_data' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret }, { type: :rna }, { type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:history_dossier) { create(:dossier, procedure:) }
    let(:hidden_dossier) { create(:dossier, procedure:, hidden_by_administration_at: Time.current) }

    def count(label) = status.degraded_data.fetch(label, 0)

    def degrade_demandeur_siret(dossier)
      DemandeurSiret.create!(dossier:, siret: '30613890001294').update_columns(external_state: 'degraded')
    end

    it 'counts the degraded champs by type and the degraded demandeur SIRETs a cron still replays' do
      expect {
        dossier.champ_data.each { it.update_columns(external_state: 'degraded') }
        history_dossier.champ_data.each { it.update_columns(external_state: 'degraded', stream: 'history:1') }
        degrade_demandeur_siret(dossier)
        degrade_demandeur_siret(hidden_dossier)
      }.to change { count('Champ SIRET') }.by(2)
        .and change { count('Champ RNA') }.by(1)
        .and change { count('SIRET lié au dossier') }.by(1)
    end
  end

  describe '#pending and #parked_by_job' do
    empty_seeds ParkedAPIEntrepriseFetch

    let(:procedure) { procedures.entreprise }

    before { procedure.update!(api_entreprise_token: JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none')) }

    def park(etablissement, code, retried_daily: false, job: 'BilansBdfJob')
      ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job:, procedure_id: procedure.id,
        arguments: [etablissement.id, procedure.id], code:, retried_daily:)
    end

    it 'leaves out of what waits the daily retries and the jobs no cron replays, and details the parking by job' do
      freeze_time
      travel_to(1.day.ago) { park(dossiers.avec_siret.etablissement, 503) }
      park(dossiers.entreprise_en_instruction.etablissement, 404, retried_daily: true)
      park(dossiers.entreprise_en_instruction.etablissement, 503, job: 'RemovedJob')

      expect(status.pending).to have_attributes(count: 1, oldest_at: 1.day.ago)
      expect(status.parked_by_job).to contain_exactly(
        have_attributes(job: 'BilansBdfJob', count: 2, count_by_code: { 503 => 1, 404 => 1 }, retried_daily: 1),
        have_attributes(job: 'RemovedJob', count: 1)
      )
    end
  end
end
