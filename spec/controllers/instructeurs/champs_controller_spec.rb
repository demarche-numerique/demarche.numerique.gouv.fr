# frozen_string_literal: true

describe Instructeurs::ChampsController, type: :controller do
  let(:instructeur) { create(:instructeur) }
  let(:instructeurs) { [instructeur] }
  let(:public_type_de_champs) { [{ type: :piece_justificative, nature: 'rib' }] }
  let(:procedure) { create(:procedure, instructeurs:, public_type_de_champs:) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.champ_data.first }

  before { sign_in(instructeur.user) }

  describe '#edit' do
    subject { get :edit, params: { dossier_id: dossier.id, public_id: champ.public_id } }

    it do
      is_expected.to have_http_status(:ok)
      # simple check to ensure no duplicate champs are created
      expect(ChampData.where(stable_id: champ.stable_id, row_id: champ.row_id).count).to eq(1)
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

      mains, others = ChampData.where(stable_id: champ.stable_id, row_id: champ.row_id).partition(&:main_stream?)
      expect((mains + others).count).to eq(2)

      main = mains.first
      expect(main.value_json['rib']).to eq(rib_params.stringify_keys)
      expect(main.external_state).to eq('fetched')

      history_champ = others.first
      expect(history_champ.stream).to start_with(Dossier::HISTORY_STREAM)
    end

    context 'when the form is submitted twice within the same second' do
      it 'keeps the first save, answers the duplicate with the same redirect and reports it' do
        expect(Sentry).to receive(:capture_exception)
          .with(an_instance_of(ActiveRecord::RecordNotUnique), hash_including(level: :warning, extra: { dossier: dossier.id, public_id: champ.public_id }))

        freeze_time do
          subject
          put :update, params: { dossier_id: dossier.id, public_id: champ.public_id, rib: rib_params }
        end

        expect(response).to redirect_to(instructeur_dossier_path(procedure, dossier))
        expect(flash[:notice]).to end_with("ont bien été modifiées.")

        main = ChampData.find_by!(stable_id: champ.stable_id, row_id: champ.row_id, stream: Dossier::MAIN_STREAM)
        expect(main.value_json['rib']).to eq(rib_params.stringify_keys)
        expect(ChampData.where(stable_id: champ.stable_id, row_id: champ.row_id).count(&:history_stream?)).to eq(1)
      end
    end

    context 'when the public_id points to a public champ that is not a RIB' do
      let(:public_type_de_champs) do
        [
          { type: :piece_justificative, nature: 'rib' },
          { type: :address, libelle: 'Adresse' },
        ]
      end

      let(:address_champ) { dossier.champ_data.find { _1.type_champ == TypeDeChamp.type_champs.fetch(:address) } }
      let(:original_address) { { 'label' => '12 rue du Test, 75000 Paris', 'postal_code' => '75000', 'city_name' => 'Paris' } }

      before { address_champ.update!(value: original_address['label'], value_json: original_address) }

      subject(:cross_type_request) do
        put :update, params: { dossier_id: dossier.id, public_id: address_champ.public_id, rib: rib_params }
      end

      it 'rejects the request and does not overwrite the address champ' do
        expect { cross_type_request }.to raise_error(ActiveRecord::RecordNotFound)

        main_address = ChampData.find_by!(dossier_id: dossier.id, stable_id: address_champ.stable_id, stream: Dossier::MAIN_STREAM)
        expect(main_address.value_json).not_to have_key('rib')
        expect(main_address.value_json).to include('label' => original_address['label'])
        expect(main_address.type).to eq('Champs::AddressChamp')
      end
    end
  end
end
