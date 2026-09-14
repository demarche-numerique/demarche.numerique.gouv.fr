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

  context 'when the dossier expired' do
    let(:external_state) { 'degraded' }

    before { dossier.update_column(:hidden_by_expired_at, 1.day.ago) }

    it 'does not spend API quota on a dossier about to be purged' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  # A champ the job cannot replay must not spend a batch slot: one blocked
  # procedure sitting first in id order would otherwise fill every run.
  shared_examples 'a procedure kept out of the batch' do
    let(:external_state) { 'degraded' }

    let(:other_dossier) { create(:dossier, procedure: create(:procedure, :published, public_type_de_champs: [{ type: :siret }])) }
    let(:other_champ) { other_dossier.champ_data.first }

    before do
      other_champ.update_columns(external_id: '30613890001294', value: '30613890001294', external_state: 'degraded')
      stub_const("#{described_class}::BATCH_SIZE", 1)
    end

    it 'spends the batch on a champ it can actually replay' do
      expect { described_class.perform_now }
        .to change { other_champ.reload.external_state }.from('degraded').to('waiting_for_job')
    end

    it 'leaves the champs it cannot replay degraded' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  context 'when API Entreprise rejected the token of the procedure' do
    before { procedure.update_column(:api_entreprise_token_rejected_at, 3.hours.ago) }

    it_behaves_like 'a procedure kept out of the batch'
  end

  context 'when the hold on a rejected token expired' do
    let(:external_state) { 'degraded' }

    let(:other_dossier) { create(:dossier, procedure:) }
    let(:other_champ) { other_dossier.champ_data.first }

    before do
      other_champ.update_columns(external_id: '30613890001294', value: '30613890001294', external_state: 'degraded')
      procedure.update_column(:api_entreprise_token_rejected_at, 2.days.ago)
    end

    it 'replays one champ as a probe and keeps the others for the next run' do
      described_class.perform_now

      expect([champ, other_champ].map { it.reload.external_state })
        .to contain_exactly('waiting_for_job', 'degraded')
    end

    it 'lets the others follow once the probe lifted the rejection' do
      procedure.forget_api_entreprise_token_rejection!

      described_class.perform_now

      expect(other_champ.reload).to be_waiting_for_job
    end
  end

  context 'when the token of the procedure is expired' do
    # Nothing marks a token rejected when it expires on its own, so the
    # rejection filter cannot see it.
    let(:procedure) { create(:procedure, :published, api_entreprise_token: JWT.encode({ exp: 1.day.ago.to_i }, nil, 'none'), public_type_de_champs: [{ type: :siret }]) }

    it_behaves_like 'a procedure kept out of the batch'
  end

  context 'when the procedure relies on an instance token that cannot work' do
    let(:procedure) { create(:procedure, :published, api_entreprise_token: nil, public_type_de_champs: [{ type: :siret }]) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('API_ENTREPRISE_KEY').and_return(nil)
    end

    it_behaves_like 'a procedure kept out of the batch'
  end
end
