# frozen_string_literal: true

RSpec.describe Cron::DiscardedEnConstructionDossiersDeletionJob, type: :job do
  describe '#perform' do
    let(:en_construction_dossier) { create(:dossier, :en_construction, hidden_by_user_at: 5.weeks.ago, hidden_by_reason: 'user_request') }
    let(:termine_dossier) { create(:dossier, :accepte, hidden_by_administration_at: 5.weeks.ago, hidden_by_reason: 'instructeur_request') }

    it 'purges only en_construction dossiers' do
      en_construction_dossier
      termine_dossier
      described_class.perform_now
      expect { en_construction_dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { termine_dossier.reload }.not_to raise_error
    end
  end
end
