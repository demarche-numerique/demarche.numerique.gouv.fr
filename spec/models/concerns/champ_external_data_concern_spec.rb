# frozen_string_literal: true

RSpec.describe ChampExternalDataConcern do
  include Dry::Monads[:result]

  describe '#save_external_error' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }
    context "add execption to the log" do
      it do
        champ.send(:save_external_error, double(inspect: 'PAN'), 404, kind: :not_found)
        expect { champ.reload }.not_to raise_error
      end
    end

    it 'persists kind on the exception' do
      champ.send(:save_external_error, StandardError.new('boom'), 503, kind: :technical_error)
      expect(champ.reload.fetch_external_data_exceptions.first.kind).to eq(:technical_error)
    end
  end

  describe '#handle_result' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }

    context 'with Failure(:not_found)' do
      it 'persists an exception with kind: :not_found' do
        allow(champ).to receive(:ready_for_external_call?).and_return(true)
        champ.fetch_later!

        result = Failure(retryable: false, error: StandardError.new('NotFound'), code: 404, kind: :not_found)
        allow(champ).to receive(:fetch_external_data).and_return(result)
        champ.fetch!

        expect(champ.reload.fetch_external_data_exceptions.first.kind).to eq(:not_found)
      end
    end

    context 'with Failure(:technical_error, retryable: true)' do
      it 'persists an exception with kind: :technical_error and raises RetryableFetchError' do
        allow(champ).to receive(:ready_for_external_call?).and_return(true)
        champ.fetch_later!

        result = Failure(retryable: true, error: StandardError.new('boom'), code: 503, kind: :technical_error)
        allow(champ).to receive(:fetch_external_data).and_return(result)

        expect { champ.fetch! }.to raise_error(RetryableFetchError)
        expect(champ.reload).to be_waiting_for_job
        expect(champ.fetch_external_data_exceptions.first.kind).to eq(:technical_error)
      end
    end
  end

  describe '#external_data_status_message' do
    let(:champ) { Champs::SiretChamp.new }

    it 'returns nil when fetched' do
      allow(champ).to receive_messages(pending?: false, external_error?: false)
      expect(champ.external_data_status_message).to be_nil
    end

    it 'returns :pending when pending and not required for conditions' do
      allow(champ).to receive_messages(pending?: true, external_error?: false, external_data_required_for_conditions?: false)
      expect(champ.external_data_status_message).to eq(:pending)
    end

    it 'returns :technical_error on external_error with non-not_found kind' do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        external_data_required_for_conditions?: false,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'x', code: 503, kind: :technical_error)]
      )
      expect(champ.external_data_status_message).to eq(:technical_error)
    end

    it 'returns nil on :not_found (handled by the validation error)' do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        external_data_required_for_conditions?: false,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'x', code: 404, kind: :not_found)]
      )
      expect(champ.external_data_status_message).to be_nil
    end

    it 'returns nil when external_data_required_for_conditions? is true' do
      allow(champ).to receive_messages(pending?: true, external_error?: false, external_data_required_for_conditions?: true)
      expect(champ.external_data_status_message).to be_nil
    end
  end

  describe 'the state machine' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }

    describe 'initial state' do
      it { expect(champ).to be_idle }
    end

    describe 'fetch_later' do
      let(:ready_for_external_call?) { true }

      before do
        allow(champ).to receive(:ready_for_external_call?).and_return(ready_for_external_call?)
        allow(champ).to receive(:fetch_external_data_later)
      end

      context 'without args' do
        subject { champ.fetch_later!; champ }

        it do
          is_expected.to be_waiting_for_job
          expect(champ).to have_received(:fetch_external_data_later)
        end

        context 'when not ready for external call' do
          let(:ready_for_external_call?) { false }

          it 'does not change the state' do
            expect(champ.may_fetch_later?).to be_falsey
            expect { subject }.to raise_error(AASM::InvalidTransition)
          end
        end
      end

      context 'with a wait arg' do
        subject { champ.fetch_later!(wait: 20); champ }

        it do
          is_expected.to be_waiting_for_job
          expect(champ).to have_received(:fetch_external_data_later).with(wait: 20)
        end
      end
    end

    describe 'fetch' do
      before do
        allow(champ).to receive(:ready_for_external_call?).and_return(true)
        champ.fetch_later!
        allow(champ).to receive(:fetch_and_handle_result)
      end

      subject { champ.fetch!; champ }

      it do
        is_expected.to be_fetching
        expect(champ).to have_received(:fetch_and_handle_result)
      end
    end

    describe 'fetch a success, now is fetched state' do
      before do
        allow(champ).to receive(:ready_for_external_call?).and_return(true)
        champ.fetch_later!

        allow(champ).to receive(:fetch_external_data).and_return(Success('some data'))
        allow(champ).to receive(:update_external_data!)
        champ.fetch!
      end

      it { expect(champ).to be_fetched }
    end

    describe 'fetch a non retryable failure, now is external_error state' do
      before do
        allow(champ).to receive(:ready_for_external_call?).and_return(true)
        champ.fetch_later!

        failure = Failure(retryable: false, error: Exception.new('nop'), code:, kind: :technical_error)
        allow(champ).to receive(:fetch_external_data).and_return(failure)
        allow(Sentry).to receive(:capture_exception)
        champ.fetch!
      end

      context 'when code is 404' do
        let(:code) { 404 }

        it do
          expect(champ).to be_external_error
          expect(Sentry).not_to have_received(:capture_exception)
        end
      end

      context 'when code is 500' do
        let(:code) { 500 }

        it { expect(Sentry).to have_received(:capture_exception) }
      end
    end

    describe 'fetch a retryable failure, now is back in waiting_for_job state' do
      before do
        allow(champ).to receive(:ready_for_external_call?).and_return(true)
        champ.fetch_later!

        failure = Failure(retryable: true, error: Exception.new('nop'), code: 404, kind: :technical_error)
        allow(champ).to receive(:fetch_external_data).and_return(failure)
      end

      subject { champ.fetch!; champ }

      it do
        expect { subject }.to raise_error(RetryableFetchError)
        expect(champ.reload).to be_waiting_for_job
      end
    end

    describe 'reset_external_data' do
      context 'from idle' do
        before { champ.reset_external_data! }

        it { expect(champ).to be_idle }
      end
      context 'from waiting_for_job' do
        before do
          allow(champ).to receive(:ready_for_external_call?).and_return(true)
          champ.fetch_later!

          allow(champ).to receive(:after_reset_external_data)
          champ.reset_external_data!
        end

        it do
          expect(champ).to be_idle
          expect(champ).to have_received(:after_reset_external_data)
        end
      end
    end
  end
end
