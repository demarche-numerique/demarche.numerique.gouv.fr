# frozen_string_literal: true

RSpec.describe APIEntreprise::Job, type: :job do
  include ActiveJob::TestHelper
  before do
    [5, 50, 100, 250].each do |pool|
      Kredis.redis.del(APIEntreprise::RateLimiter.remaining_key(pool), APIEntreprise::RateLimiter.reset_key(pool))
    end
  end

  let(:procedure) { procedures.entreprise }
  let(:etablissement) { create(:etablissement) }
  let(:fetch) { ParkedAPIEntrepriseFetch.find_by(etablissement:, job: 'ExercicesJob') }
  let(:result) { Dry::Monads::Success({ entreprise_capital_social: 1 }) }

  before do
    procedure.update!(api_entreprise_token: JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none'))
    allow(APIEntreprise::HealthChecker).to receive(:provider_up?).and_return(true)
    allow(APIEntreprise::RateLimiter).to receive(:throttled?).and_return(false)
    allow_any_instance_of(APIEntreprise::ExercicesAdapter).to receive(:to_params).and_return(result)
  end

  def perform = APIEntreprise::ExercicesJob.perform_now(etablissement.id, procedure.id)

  describe 'before calling the API' do
    context 'while the provider is down' do
      before { allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with('dgfip/chiffre_affaires').and_return(false) }

      it 'waits in the table instead of in Sidekiq' do
        expect_any_instance_of(APIEntreprise::ExercicesAdapter).not_to receive(:to_params)

        expect { perform }.not_to raise_error
        expect(fetch).to have_attributes(code: 503, procedure_id: procedure.id, job_arguments: [etablissement.id, procedure.id])
      end

      it 'does not log the wait as an error' do
        expect(ActiveJob::Base.logger).not_to receive(:error)

        perform
      end
    end

    context 'while the pool is throttled' do
      before { allow(APIEntreprise::RateLimiter).to receive(:throttled?).with(250).and_return(true) }

      it 'waits in the table' do
        expect { perform }.not_to raise_error
        expect(fetch.code).to eq(429)
      end
    end

    context 'when the token of the procedure cannot work' do
      before { procedure.update!(api_entreprise_token: JWT.encode({ exp: 1.day.ago.to_i }, nil, 'none')) }

      it 'gives up without calling the API' do
        expect_any_instance_of(APIEntreprise::ExercicesAdapter).not_to receive(:to_params)

        perform

        expect(fetch).to be_nil
      end

      it 'lets the cron replay a previous wait once the token works again' do
        ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 503)
        fetch.update_column(:enqueued_at, 1.hour.ago)

        perform

        expect(fetch.reload.enqueued_at).to be_nil
      end
    end
  end

  describe 'after calling the API' do
    context 'when it answers' do
      it 'forgets a previous wait' do
        ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 503)

        perform

        expect(fetch).to be_nil
      end
    end

    context 'when reading the answer fails' do
      before { allow_any_instance_of(APIEntreprise::ExercicesAdapter).to receive(:to_params).and_raise(TypeError, 'boom') }

      it 'leaves the retries to Sidekiq alone' do
        ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 503)

        expect { perform }.to raise_error(TypeError, 'boom')
        expect(fetch).to be_nil
      end
    end

    context 'when saving the answer fails' do
      before { allow_any_instance_of(Etablissement).to receive(:update!).and_raise(StandardError, 'boom') }

      it 'leaves the retries to Sidekiq alone' do
        ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 503)

        expect { perform }.to raise_error(StandardError, 'boom')
        expect(fetch).to be_nil
      end
    end

    context 'when the provider fails' do
      let(:result) { Dry::Monads::Failure(type: :service_unavailable, code: 503, retryable: true, raw_response: nil) }

      it 'waits in the table instead of raising' do
        expect { perform }.not_to raise_error
        expect(fetch.code).to eq(503)
      end
    end

    context 'when the provider cannot serve this etablissement for now' do
      let(:result) { Dry::Monads::Failure(type: :unavailable_for_entity, code: 502, retryable: true, raw_response: nil) }

      def park_daily(times)
        times.times { ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 502, retried_daily: true) }
      end

      it 'waits in the table to be retried once a day' do
        expect { perform }.not_to raise_error
        expect(fetch).to have_attributes(code: 502, daily_failures: 1)
      end

      it 'retries it a third day' do
        park_daily(2)

        perform

        expect(fetch.daily_failures).to eq(3)
      end

      it 'gives up once the three daily retries failed' do
        park_daily(3)

        perform

        expect(fetch).to be_nil
      end
    end

    context 'when API Entreprise refuses the token or the scope' do
      let(:result) { Dry::Monads::Failure(type: :forbidden, code: 403, retryable: false, raw_response: nil) }

      it 'gives up without blaming the token of the procedure' do
        ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 503)

        perform

        expect(fetch).to be_nil
        expect(procedure.reload.api_entreprise_token_rejected_at).to be_nil
      end
    end

    context 'when the data does not exist' do
      let(:result) { Dry::Monads::Failure(type: :not_found, code: 404, retryable: false, raw_response: nil) }

      it 'gives up for good' do
        ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'ExercicesJob', procedure_id: procedure.id, arguments: [etablissement.id, procedure.id], code: 503)

        perform

        expect(fetch).to be_nil
      end
    end
  end

  context 'when the etablissement is gone' do
    it 'drops the job' do
      expect { APIEntreprise::ExercicesJob.perform_now(0, procedure.id) }.not_to raise_error
      expect(ParkedAPIEntrepriseFetch.where(etablissement_id: 0)).to be_empty
    end
  end

  describe '#api_pool' do
    it 'returns the correct pool for each job class' do
      expect(APIEntreprise::ExtraitKbisJob.new.api_pool).to eq(250)
      expect(APIEntreprise::TvaJob.new.api_pool).to eq(250)
      expect(APIEntreprise::ExercicesJob.new.api_pool).to eq(250)
      expect(APIEntreprise::AssociationJob.new.api_pool).to eq(250)
      expect(APIEntreprise::BilansBdfJob.new.api_pool).to eq(250)
      expect(APIEntreprise::EffectifsJob.new.api_pool).to eq(50)
      expect(APIEntreprise::EffectifsAnnuelsJob.new.api_pool).to eq(50)
      expect(APIEntreprise::AttestationSocialeJob.new.api_pool).to eq(100)
      expect(APIEntreprise::AttestationFiscaleJob.new.api_pool).to eq(5)
    end
  end

  describe '.provider_down?' do
    before { allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with('dgfip/numero_tva').and_return(false) }

    it 'checks the provider of the job class' do
      expect(APIEntreprise::TvaJob.provider_down?).to be true
      expect(APIEntreprise::ExtraitKbisJob.provider_down?).to be false
    end
  end

  describe 'PING_KEY_BY_JOB completeness' do
    it 'covers all job classes in app/jobs/api_entreprise/' do
      job_class_names = Rails.root.glob('app/jobs/api_entreprise/*_job.rb')
        .map { "APIEntreprise::#{File.basename(it, '.rb').camelize}".constantize }
        .filter { it < described_class }
        .map { it.name.demodulize }

      expect(described_class::PING_KEY_BY_JOB.keys).to match_array(job_class_names)
    end
  end

  describe 'sidekiq retry configuration' do
    subject(:options) { described_class.get_sidekiq_options }

    it 'defers Sentry reporting until the 8th attempt while keeping native retry' do
      expect(options["attempt_threshold"]).to eq(8)
      expect(options["retry"]).to eq(ActiveJob::RetryOnStandardError::MAX_ATTEMPTS_JOBS)
    end
  end
end
