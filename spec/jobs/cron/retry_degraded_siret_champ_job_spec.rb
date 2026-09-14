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

    it 'puts it back in the queue, in a state that does not block the user' do
      expect { described_class.perform_now }
        .to change { champ.reload.external_state }.from('degraded').to('waiting_for_fix')
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

  context 'with a champ whose retry is already scheduled' do
    let(:external_state) { 'waiting_for_fix' }

    it 'does not enqueue it twice' do
      expect { described_class.perform_now }.not_to have_enqueued_job(ChampFetchExternalDataJob)
    end
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

  # The buffer copy is what a submission puts on the main stream, and
  # champ_upsert_by! clones external_state into it: leaving it degraded either
  # strands the champ, or undoes the repair the cron just made on main.
  context 'with a degraded copy on the user buffer stream' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret, stable_id: 42 }]) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:champ) { dossier.champ_data.find(&:main_stream?) }
    let(:external_state) { 'degraded' }

    let!(:buffer_champ) do
      dossier.with_update_stream(dossier.user) do
        dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(42), updated_by: 'usager')
      end
    end

    it 'replays it too, not just the main stream' do
      expect { described_class.perform_now }
        .to change { buffer_champ.reload.external_state }.from('degraded').to('waiting_for_fix')
    end

    it 'leaves the champ fetched once the dossier is submitted' do
      stub_request(:get, /entreprise.api.gouv.fr/)
        .to_return(status: 200, body: File.read('spec/fixtures/files/api_entreprise/etablissements.json'))

      described_class.perform_now
      perform_enqueued_jobs
      dossier.reload.merge_user_buffer_stream!

      expect(dossier.reload.champ_data.find(&:main_stream?).external_state).to eq('fetched')
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

  # Discarding hides the dossiers the administration could see, not the brouillons.
  context 'when the procedure was discarded' do
    let(:external_state) { 'degraded' }

    before { procedure.discard! }

    it 'does not spend API quota on a dossier nobody will instruct' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  context 'when the instance token cannot work' do
    let(:procedure) { create(:procedure, :published, api_entreprise_token: nil, public_type_de_champs: [{ type: :siret }]) }
    let(:external_state) { 'degraded' }

    before { allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(true) }

    it 'leaves them degraded rather than replaying a call that cannot succeed' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  context 'when API Entreprise rejected the token of the procedure' do
    let(:external_state) { 'degraded' }

    before { procedure.update_column(:api_entreprise_token_rejected_at, 3.hours.ago) }

    it 'does not retry: no attempt converges until the token is renewed' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end
end
