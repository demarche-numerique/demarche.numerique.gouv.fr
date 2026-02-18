# frozen_string_literal: true

describe Champs::QuotientFamilialChamp, type: :model do
  let(:types_de_champ_public) { [{ type: :quotient_familial }] }
  let(:procedure) { create(:procedure, types_de_champ_public:, for_individual: true) }
  let(:dossier) { create(:dossier, procedure:, for_tiers: false, for_procedure_preview: false) }
  let(:champ) { dossier.champs.first }
  let!(:fci) { create(:france_connect_information, user: dossier.user) }

  describe '#ready_for_external_call?' do
    subject { champ.ready_for_external_call? }

    it do
      is_expected.to be_truthy
    end

    context 'when dossier is for procedure preview' do
      before { dossier.update(for_procedure_preview: true) }

      it do
        is_expected.to be_falsey
      end
    end

    context 'when procedure is not for individual' do
      before do
        procedure.update(for_individual: false)
        dossier.reload
      end

      it do
        is_expected.to be_falsey
      end
    end

    context 'when dossier is for tiers' do
      before { dossier.update(for_tiers: true) }

      it do
        is_expected.to be_falsey
      end
    end

    context 'when user has never logged in with FC' do
      let!(:fci) {}
      it 'set recovered_qf_data to false' do
        expect(dossier.user_from_france_connect?).to eq(false)
        is_expected.to be_falsey
      end
    end
  end
end
