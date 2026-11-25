# frozen_string_literal: true

describe Manager::AdministrateurCreationRequestsController, type: :controller do
  let(:requester) { create(:super_admin, :with_otp) }
  let(:validator) { create(:super_admin, :with_otp) }
  let(:super_admin) { validator }
  let(:emails) { Array.new(11) { "agent.#{it}@numerique.gouv.fr" } }
  let!(:creation_request) { AdministrateurCreationRequest.create!(requester:, emails:, state: :pending, otp_verified: true) }

  before { sign_in super_admin }

  describe '#show' do
    render_views

    before { get :show, params: { id: creation_request.id } }

    context 'for the requester' do
      let(:super_admin) { requester }

      it 'shows the link to share, without the approval form' do
        expect(response.body).to include('Lien à transmettre à un autre super admin', manager_administrateur_creation_request_url(creation_request))
        expect(response.body).not_to include(approve_manager_administrateur_creation_request_path(creation_request))
      end
    end

    context 'for another super admin' do
      it 'shows the approval form' do
        expect(response.body).to include(requester.email, 'agent.10@numerique.gouv.fr', 'numerique.gouv.fr · 11', 'name="otp_attempt"')
        expect(response.body).to include('Valider la création de 11 comptes administrateurs')
      end
    end

    context 'when the request has expired' do
      let!(:creation_request) { AdministrateurCreationRequest.create!(requester:, emails:, state: :pending, created_at: 25.hours.ago) }

      it do
        expect(response.body).to include('Cette demande a expiré')
        expect(response.body).not_to include('name="otp_attempt"')
      end
    end

    context 'when the accounts are being created' do
      let(:emails) { ['a@numerique.gouv.fr', 'b@numerique.gouv.fr', 'c@numerique.gouv.fr'] }
      let!(:creation_request) { AdministrateurCreationRequest.create!(requester:, emails:, state: :approved, results: { 'a@numerique.gouv.fr' => 'created' }) }

      it 'keeps showing the progress until every address is processed' do
        expect(response.body).to include('Création des comptes en cours.')
        expect(response.body).not_to include('Administrateur créé.')
      end
    end
  end

  describe '#approve' do
    let(:otp_attempt) { current_otp_for(super_admin) }

    subject { post :approve, params: { id: creation_request.id, otp_attempt: } }

    it 'approves the request and creates the accounts in a job' do
      expect { subject }.to have_enqueued_job(AdministrateurCreationRequestJob).with(creation_request)

      expect(creation_request.reload).to have_attributes(state: 'approved', validator_id: validator.id)
      expect(response).to redirect_to(manager_administrateurs_path)
    end

    it_behaves_like "a manager action gated by a fresh super-admin OTP" do
      let(:other_request) { AdministrateurCreationRequest.create!(requester:, emails:, state: :pending) }
      let(:action_matcher) { have_enqueued_job(AdministrateurCreationRequestJob) }
      let(:replay_subject) { -> { post :approve, params: { id: other_request.id, otp_attempt: } } }
    end

    context 'when the requester approves its own request' do
      let(:super_admin) { requester }

      it do
        expect { subject }.not_to have_enqueued_job(AdministrateurCreationRequestJob)
        expect(creation_request.reload).to be_pending
        expect(flash[:alert]).to include('un autre super admin')
      end
    end

    context 'when the requester has been deleted' do
      before { requester.destroy! }

      it do
        expect { subject }.to have_enqueued_job(AdministrateurCreationRequestJob)
        expect(creation_request.reload).to be_approved
      end
    end

    context 'when the request is replayed' do
      before { creation_request.approve!(create(:super_admin)) }

      it do
        expect { subject }.not_to have_enqueued_job(AdministrateurCreationRequestJob)
        expect(flash[:alert]).to eq('Cette demande a déjà été validée.')
      end
    end

    context 'when the request has expired' do
      before { creation_request.update!(created_at: 25.hours.ago) }

      it 'does not use up an OTP attempt' do
        expect { subject }.not_to change { validator.reload.failed_attempts }
        expect(creation_request.reload).to be_pending
        expect(flash[:alert]).to eq('Cette demande a expiré.')
      end
    end
  end

  describe '#refuse' do
    subject { post :refuse, params: { id: creation_request.id } }

    it do
      subject
      expect(creation_request.reload).to have_attributes(state: 'refused', validator_id: validator.id)
    end

    context 'for the requester' do
      let(:super_admin) { requester }

      it do
        subject
        expect(creation_request.reload).to be_pending
      end
    end
  end

  describe '#cancel' do
    let(:super_admin) { requester }

    it 'cancels the request' do
      post :cancel, params: { id: creation_request.id }

      expect(creation_request.reload).to be_cancelled
      expect(response).to redirect_to(new_manager_administrateur_path)
    end

    it 'goes back to the prefilled form to edit the list' do
      post :cancel, params: { id: creation_request.id, edit: true }

      expect(creation_request.reload).to be_cancelled
      expect(response).to redirect_to(new_manager_administrateur_path(from: creation_request.id))
    end

    context 'for another super admin' do
      let(:super_admin) { validator }

      it do
        post :cancel, params: { id: creation_request.id }
        expect(creation_request.reload).to be_pending
      end
    end
  end
end
