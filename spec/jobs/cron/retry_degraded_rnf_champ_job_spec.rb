# frozen_string_literal: true

RSpec.describe Cron::RetryDegradedRNFChampJob, type: :job do
  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :rnf }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:rnf_token) { 'rnf-token' }

  before do
    champ.update_columns(external_id: '075-FDD-00003-01', external_state: 'degraded')
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('RNF_TOKEN').and_return(rnf_token)
  end

  it 'puts the champ back in the queue' do
    expect { described_class.perform_now }
      .to change { champ.reload.external_state }.from('degraded').to('waiting_for_fix')
  end

  context 'while API Entreprise is down or throttled' do
    before do
      allow(APIEntreprise::HealthChecker).to receive(:provider_up?).and_return(false)
      allow(APIEntreprise::RateLimiter).to receive(:throttled?).and_return(true)
    end

    it 'replays it anyway: RNF does not go through API Entreprise' do
      expect { described_class.perform_now }
        .to change { champ.reload.external_state }.from('degraded').to('waiting_for_fix')
    end
  end

  context 'when the procedure has no usable API Entreprise token' do
    let(:procedure) { create(:procedure, :published, api_entreprise_token: nil, public_type_de_champs: [{ type: :rnf }]) }

    before { allow(ENV).to receive(:[]).with('API_ENTREPRISE_KEY').and_return(nil) }

    it 'replays it anyway: RNF has a token of its own' do
      expect { described_class.perform_now }
        .to change { champ.reload.external_state }.from('degraded').to('waiting_for_fix')
    end
  end

  context 'without a RNF token' do
    let(:rnf_token) { nil }

    it 'leaves it alone' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end
end
