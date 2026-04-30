# frozen_string_literal: true

describe Instructeurs::RdvsController, type: :controller do
  let(:instructeur) { create(:instructeur) }
  let(:dossier) { create(:dossier, :en_instruction) }
  let(:rdv_connection) { create(:rdv_connection, instructeur: instructeur) }

  before do
    sign_in(instructeur.user)
    instructeur.assign_to_procedure(dossier.procedure)
    instructeur.rdv_connection = rdv_connection
  end

  describe '#create' do
    subject { post :create, params: { dossier_id: dossier.id, procedure_id: dossier.procedure.id } }

    let(:rdv_plan_result) { instance_double(Dry::Monads::Result::Success, success?: true, value!: create(:rdv, dossier: dossier, instructeur: instructeur)) }

    before do
      allow_any_instance_of(RdvService).to receive(:create_rdv_plan).and_return(rdv_plan_result)
    end

    it 'creates a new rdv and redirects to rdv plan url' do
      subject
      expect(response).to redirect_to(rdv_plan_result.value!.rdv_plan_url)
    end

    context 'when the dossier has no individual and no FranceConnect information' do
      let(:dossier) { create(:dossier, :en_instruction, individual: nil, user: create(:user, france_connect_informations: [])) }

      it 'creates a new rdv with default names and does not raise an error' do
        expect { subject }.not_to raise_error
        expect(response).to redirect_to(rdv_plan_result.value!.rdv_plan_url)
      end
    end
  end
end
