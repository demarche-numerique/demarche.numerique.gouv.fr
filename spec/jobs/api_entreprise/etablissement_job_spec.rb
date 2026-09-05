# frozen_string_literal: true

RSpec.describe APIEntreprise::EtablissementJob, type: :job do
  include Dry::Monads[:result]

  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:etablissement) { create(:etablissement, adresse: nil, siret: '01234567891011') }

  subject { described_class.new.perform(etablissement.id, procedure.id) }

  before { champ.update_columns(etablissement_id: etablissement.id, external_state: 'degraded') }

  context 'when the backfill succeeds' do
    before do
      allow(APIEntrepriseService).to receive(:update_etablissement_from_degraded_mode).and_return(etablissement)
    end

    it { expect { subject }.not_to raise_error }
  end

  context 'when the backfill hits a transient failure' do
    before do
      allow(APIEntrepriseService).to receive(:update_etablissement_from_degraded_mode)
        .and_return(Failure(type: :server_error, code: 503, retryable: true, raw_response: nil))
    end

    it 'raises so the job retries instead of waiting for the cron' do
      expect { subject }.to raise_error(APIEntreprise::Job::RetryableError, /server_error/)
    end
  end

  context 'when the backfill cannot converge' do
    before do
      allow(APIEntrepriseService).to receive(:update_etablissement_from_degraded_mode).and_return(nil)
    end

    it 'does not retry: no attempt would converge' do
      expect { subject }.not_to raise_error
    end
  end
end
