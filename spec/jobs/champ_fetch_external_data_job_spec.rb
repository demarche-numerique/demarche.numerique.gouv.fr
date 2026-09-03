# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChampFetchExternalDataJob, type: :job do
  include Dry::Monads[:result]

  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :rnf }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:external_id) { champ.external_id }

  describe 'perform' do
    let(:external_state) { 'waiting_for_job' }

    before do
      champ.update_columns(external_state:)
      allow(champ).to receive(:fetch!)
      described_class.new.perform(champ, external_id)
    end

    context 'when external_id matches the champ external_id' do
      it { expect(champ).to have_received(:fetch!) }
    end

    context 'when external_id does not match the champ external_id' do
      let(:external_id) { "something else" }

      it { expect(champ).not_to have_received(:fetch!) }
    end

    context 'when champ is not in waiting_for_job state' do
      let(:external_state) { 'fetched' }

      it { expect(champ).not_to have_received(:fetch!) }
    end
  end

  describe 'error handling and backoff strategy' do
    let(:error) { StandardError.new('Retryable error') }
    let(:failure) { Dry::Monads::Failure(retryable: true, error:, code: 504) }

    before do
      champ.update_column(:external_state, 'waiting_for_job')
      allow_any_instance_of(Champs::RNFChamp).to receive(:fetch_external_data).and_return(failure)
    end

    context 'when a retryable error occurs' do
      it 'retries then transitions to external_error after max attempts' do
        described_class.perform_later(champ, external_id)

        # Drain the queue iteratively without recursive inline execution.
        # The non-block form of perform_enqueued_jobs (flush mode) performs
        # currently-enqueued jobs one pass at a time. Each retry_on just
        # enqueues the next attempt without executing it inline, avoiding
        # the cascade that causes hangs with Rails 7.2.3+.
        3.times do
          perform_enqueued_jobs(only: ChampFetchExternalDataJob)
        rescue StandardError
          # After 3 RetryableFetchError retries, the exhaust block raises err.cause
        end

        champ.reload

        expect(champ).to be_external_error
        expect(champ.fetch_external_data_exceptions.size).to eq(3)
      end
    end

    context 'when retries are exhausted on a siret champ' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:external_id) { '41816609600051' }

      before do
        champ.update_columns(external_id:, external_state: 'waiting_for_job')
        allow_any_instance_of(Champs::SiretChamp).to receive(:fetch_external_data).and_return(failure)
      end

      it 'converges to the degraded state instead of external_error' do
        described_class.perform_later(champ, external_id)

        3.times do
          perform_enqueued_jobs(only: ChampFetchExternalDataJob)
        rescue StandardError
        end

        champ.reload

        expect(champ).to be_degraded
        expect(champ.etablissement).to be_as_degraded_mode
        expect(champ.fetch_external_data_exceptions.last.code).to eq(504)
      end

      context 'and the user replaced the SIRET during the last attempt' do
        before do
          attempt = 0
          allow_any_instance_of(Champs::SiretChamp).to receive(:fetch_external_data) do |c|
            attempt += 1
            c.update_columns(external_id: '41816609600069') if attempt == 3
            failure
          end
        end

        it 'does not build a stub for the identifier the user left behind' do
          described_class.perform_later(champ, external_id)

          3.times do
            perform_enqueued_jobs(only: ChampFetchExternalDataJob)
          rescue StandardError
          end

          champ.reload

          expect(champ).not_to be_degraded
          expect(champ.etablissement).to be_nil
        end
      end

      context 'and the exhaustion handler itself raises' do
        let(:boom) { StandardError.new('champ was reset meanwhile') }

        before do
          allow_any_instance_of(Champs::SiretChamp)
            .to receive(:handle_exhausted_external_data_retries!).and_raise(boom)
        end

        it 'reports it to Sentry instead of letting the exception escape' do
          expect(Sentry).to receive(:capture_exception).with(boom)
          expect(Sentry).to receive(:capture_exception).with(error)

          described_class.perform_later(champ, external_id)

          expect { 3.times { perform_enqueued_jobs(only: ChampFetchExternalDataJob) } }.not_to raise_error
        end

        it 'settles the champ instead of leaving it pending forever' do
          allow(Sentry).to receive(:capture_exception)

          described_class.perform_later(champ, external_id)

          3.times do
            perform_enqueued_jobs(only: ChampFetchExternalDataJob)
          rescue StandardError
          end

          expect(champ.reload).to be_external_error
        end
      end
    end
  end
end
