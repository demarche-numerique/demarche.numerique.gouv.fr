# frozen_string_literal: true

RSpec.describe Cron::DiscardedTermineDossiersDeletionJob, type: :job do
  describe '#perform' do
    let(:termine_dossier) do
      create(:dossier, :accepte,
             hidden_by_user_at: 5.weeks.ago,
             hidden_by_administration_at: 5.weeks.ago,
             hidden_by_reason: 'instructeur_request')
    end
    let(:brouillon_dossier) { create(:dossier, :brouillon, hidden_by_user_at: 5.weeks.ago, hidden_by_reason: 'user_request') }

    it 'purges only termine dossiers' do
      termine_dossier
      brouillon_dossier
      described_class.perform_now
      expect { termine_dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { brouillon_dossier.reload }.not_to raise_error
    end
  end
end
