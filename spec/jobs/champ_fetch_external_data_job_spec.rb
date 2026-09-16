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

    context 'when the champ waits for its cron retry' do
      let(:external_state) { 'waiting_for_fix' }

      it { expect(champ).to have_received(:fetch!) }
    end

    context 'when the champ has nothing left to fetch' do
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
          # After 3 RetryableFetchError retries, the exhaust block reports the error
        end

        champ.reload

        expect(champ).to be_external_error
        expect(champ.fetch_external_data_exceptions.size).to eq(3)
      end
    end
  end

  describe 'dossier timestamps' do
    before do
      champ.update_column(:external_state, 'waiting_for_job')
      allow_any_instance_of(Champs::RNFChamp).to receive(:fetch_external_data).and_return(result)
    end

    context 'when the API did not answer' do
      let(:result) { Dry::Monads::Failure(degraded: true, value: external_id, error: StandardError.new('boom'), code: 502) }

      it 'does not make the dossier look freshly modified to its instructeur' do
        expect { described_class.new.perform(champ, external_id) }
          .not_to change { dossier.reload.updated_at }

        expect(champ.reload).to be_degraded
      end
    end

    context 'when the data arrives' do
      let(:result) { Dry::Monads::Success(data: { 'title' => 'Fondation' }, value_json: { 'title' => 'Fondation' }) }

      it 'dates the dossier, so the API updatedSince filter returns it again' do
        expect { described_class.new.perform(champ, external_id) }
          .to change { dossier.reload.updated_at }

        expect(champ.reload).to be_fetched
      end
    end
  end
end
