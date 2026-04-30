# frozen_string_literal: true

describe CreateAvisService do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
  let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }
  let(:expert_email) { 'expert@exemple.fr' }

  subject(:result) do
    CreateAvisService.call(
      dossier:,
      instructeur_or_expert: instructeur,
      batch: true,
      params: { emails: [expert_email], introduction: 'Merci de donner votre avis.' }
    )
  end

  describe '#call' do
    context 'when everything goes well' do
      it 'creates an avis for the dossier' do
        expect { result }.to change { dossier.avis.count }.by(1)
      end
    end

    context 'when a concurrent job raises RecordNotUnique on ExpertsProcedure creation' do
      it 'creates the avis without raising an error' do
        existing_ep = create(:experts_procedure, procedure:)
        allow(ExpertsProcedure).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordNotUnique)
        allow(ExpertsProcedure).to receive(:find_by!).and_return(existing_ep)

        expect { result }.not_to raise_error
      end
    end
  end
end
