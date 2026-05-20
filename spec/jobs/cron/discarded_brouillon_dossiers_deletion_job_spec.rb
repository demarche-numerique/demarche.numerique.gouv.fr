# frozen_string_literal: true

RSpec.describe Cron::DiscardedBrouillonDossiersDeletionJob, type: :job do
  describe '#perform' do
    let(:brouillon_dossier) { create(:dossier, :brouillon, hidden_by_user_at: 5.weeks.ago, hidden_by_reason: 'user_request') }
    let(:en_construction_dossier) { create(:dossier, :en_construction, hidden_by_user_at: 5.weeks.ago, hidden_by_reason: 'user_request') }

    it 'purges only brouillon dossiers' do
      brouillon_dossier
      en_construction_dossier
      described_class.perform_now
      expect { brouillon_dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { en_construction_dossier.reload }.not_to raise_error
    end
  end
end
