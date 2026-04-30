# frozen_string_literal: true

describe Instructeurs::ChampsController, type: :controller do
  let(:instructeur) { create(:instructeur) }
  let(:instructeurs) { [instructeur] }
  let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'rib' }] }
  let(:procedure) { create(:procedure, instructeurs:, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.champs.first }

  before { sign_in(instructeur.user) }

  describe '#edit' do
    subject { get :edit, params: { dossier_id: dossier.id, public_id: champ.public_id } }

    it do
      is_expected.to have_http_status(:ok)
      # simple check to ensure no duplicate champs are created
      expect(Champ.where(stable_id: champ.stable_id, row_id: champ.row_id).count).to eq(1)
    end

    context 'when the instructeur is not assigned to the dossier' do
      let(:instructeurs) { [] }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe '#update' do
    let(:rib_params) do
      {
        account_holder: "John Doe",
        bank_name: "Bank of Tests",
        bic: "TESTBIC123",
        iban: "FR76TESTBIC1234567890123456",
      }
    end

    before { champ.update!(external_state: :fetched) }

    subject { put :update, params: { dossier_id: dossier.id, public_id: champ.public_id, rib: rib_params } }

    it 'updates the RIB champ and redirects' do
      is_expected.to redirect_to(instructeur_dossier_path(procedure, dossier))
      expect(flash[:notice]).to end_with("ont bien été modifiées.")

      mains, others = Champ.where(stable_id: champ.stable_id, row_id: champ.row_id).partition { it.stream == 'main' }
      expect((mains + others).count).to eq(2)

      main = mains.first
      expect(main.value_json['rib']).to eq(rib_params.stringify_keys)
      expect(main.external_state).to eq('fetched')

      history_champ = others.first
      expect(history_champ.stream).to start_with('history:')
    end
  end
end
