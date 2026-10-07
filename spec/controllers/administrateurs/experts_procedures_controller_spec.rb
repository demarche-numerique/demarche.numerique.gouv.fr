# frozen_string_literal: true

describe Administrateurs::ExpertsProceduresController, type: :controller do
  let(:admin) { administrateurs.default }
  let(:procedure) { create :procedure, administrateur: admin }

  before do
    sign_in(admin.user)
  end

  describe '#index' do
    subject do
      get :index, params: { procedure_id: procedure.id }
    end

    context 'nominal' do
      before { subject }

      it { expect(response.status).to eq 200 }
    end

    context 'with a revoked expert' do
      let!(:revoked) { create(:experts_procedure, procedure:, expert: create(:expert), revoked_at: 1.day.ago) }

      context 'when the procedure manages its experts with a predefined list' do
        let(:procedure) { create :procedure, administrateur: admin, experts_require_administrateur_invitation: true }

        it 'hides it' do
          subject
          expect(assigns(:experts_procedure)).not_to include(revoked)
        end
      end

      context 'when the procedure lets instructeurs invite the experts they want' do
        it 'lists it: the revocation is dormant, so that expert does have access' do
          subject
          expect(assigns(:experts_procedure)).to include(revoked)
        end
      end
    end
  end

  describe '#create' do
    let(:expert) { create(:expert) }
    let(:expert2) { create(:expert) }
    let(:procedure) { create :procedure, administrateur: admin, experts_require_administrateur_invitation: true }

    subject { post :create, params: params }

    context 'when inviting multiple valid experts' do
      let(:params) { { procedure_id: procedure.id, emails: [expert.email, "new@expert.fr"] } }

      it 'creates experts' do
        subject
        expect(procedure.experts.map(&:email)).to match_array([expert.email, "new@expert.fr"])
        expect(flash.notice).to be_present
        expect(assigns(:maybe_typos)).to eq([])
        expect(response).to redirect_to(admin_procedure_experts_path(procedure))
      end
    end

    context 'when inviting expert using an email with typos' do
      let(:params) { { procedure_id: procedure.id, emails: ['martin@oraneg.fr'] } }
      render_views
      it 'warns' do
        subject
        expect(flash.alert).to be_present
        expect(assigns(:maybe_typos)).to eq([['martin@oraneg.fr', 'martin@orange.fr']])
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when forcing email with typos' do
      let(:final_email) { 'martin@oraneg.fr' }
      let(:params) { { procedure_id: procedure.id, final_email: } }

      it 'works' do
        subject
        created_user = User.where(email: final_email).first
        expect(created_user).to be_an_instance_of(User)
        expect(created_user.expert).to be_an_instance_of(Expert)
        expect(procedure.experts.include?(created_user.expert)).to be_truthy
        expect(flash.notice).to include(final_email)
        expect(response).to redirect_to(admin_procedure_experts_path(procedure))
      end
    end
  end

  describe '#update' do
    let(:expert) { create(:expert) }
    let(:expert_procedure) { create(:experts_procedure, procedure: procedure, expert: expert) }

    subject do
      put :update, params: {
        id: expert_procedure.id,
        procedure_id: procedure.id,
        experts_procedure: {
          allow_decision_access: true,
        },
      }, format: :js
    end

    before do
      subject
    end

    it 'updates the record' do
      expect(expert_procedure.allow_decision_access).to be false
      subject
      expect(expert_procedure.reload.allow_decision_access).to be true
    end
  end

  describe '#delete' do
    let(:expert) { create(:expert) }
    let(:expert_procedure) { ExpertsProcedure.create(expert: expert, procedure: procedure) }

    subject do
      delete :destroy, params: { procedure_id: procedure.id, id: expert_procedure.id }
    end

    before do
      subject
      expert_procedure.reload
    end

    context 'of multiple experts' do
      it do
        expect(expert_procedure.revoked_at).to be_present
        expect(flash.notice).to be_present
        expect(response).to redirect_to(admin_procedure_experts_path(procedure))
      end
    end
  end
end
