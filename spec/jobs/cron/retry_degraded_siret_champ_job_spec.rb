# frozen_string_literal: true

RSpec.describe Cron::RetryDegradedSiretChampJob, type: :job do
  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:insee_up) { true }

  before do
    champ.update_columns(external_id: '30613890001294', value: '30613890001294', external_state:)
    allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(insee_up)
  end

  context 'with a degraded champ' do
    let(:external_state) { 'degraded' }

    it 'puts it back in the queue' do
      expect { described_class.perform_now }
        .to change { champ.reload.external_state }.from('degraded').to('waiting_for_job')
    end

    it 'does not make the dossier look freshly modified to its instructeur' do
      expect { described_class.perform_now }.not_to change { dossier.reload.updated_at }
    end

    it 'schedules the fetch, spread over the window instead of all at once' do
      expect { described_class.perform_now }
        .to have_enqueued_job(ChampFetchExternalDataJob).with(champ, '30613890001294')
    end

    context 'while INSEE is still down' do
      let(:insee_up) { false }

      it { expect { described_class.perform_now }.not_to change { champ.reload.external_state } }
    end
  end

  context 'with a champ that is not degraded' do
    let(:external_state) { 'external_error' }

    it { expect { described_class.perform_now }.not_to change { champ.reload.external_state } }
  end

  context 'while the API Entreprise pool is throttled' do
    let(:external_state) { 'degraded' }

    before { allow(APIEntreprise::RateLimiter).to receive(:throttled?).and_return(true) }

    it 'waits instead of adding to the flood' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  context 'with a degraded champ kept as a history copy' do
    let(:external_state) { 'degraded' }

    before { champ.update_column(:stream, 'history:1') }

    it 'leaves the archive alone' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  context 'when the dossier was hidden by its user' do
    let(:external_state) { 'degraded' }

    before { dossier.update_column(:hidden_by_user_at, 1.day.ago) }

    it 'does not spend API quota on a dossier nobody will read' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end
end
