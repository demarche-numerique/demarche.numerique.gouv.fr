# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChampFetchExternalDataJob, type: :job do
  include Dry::Monads[:result]

  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :rnf }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champs.first }
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
      it 'tries 5 times and the final state is external_error' do
        assert_performed_jobs 5 do
          described_class.perform_later(champ, external_id) rescue StandardError
        end

        champ.reload

        expect(champ).to be_external_error
        expect(champ.fetch_external_data_exceptions.size).to eq(5)
      end
    end
  end
end
