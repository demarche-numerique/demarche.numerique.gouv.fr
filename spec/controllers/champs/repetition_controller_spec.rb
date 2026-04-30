# frozen_string_literal: true

describe Champs::RepetitionController, type: :controller do
  before { sign_in dossier.user }

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, mandatory: true, children: [{ libelle: 'Nom' }, { type: :integer_number, libelle: 'Age' }] }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:repetition) { dossier.project_champs_public.find(&:repetition?) }

  describe 'ensure_legitimate_access' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.project_champs_public.first }

    it 'returns not found when the champ is not a repetition' do
      post :add, params: { dossier_id: dossier, stable_id: champ.stable_id }, format: :turbo_stream
      expect(response).to have_http_status(:not_found)
    end

    context 'when instructeur is signed in and try to add a repetition to a dossier en instruction' do
      let(:instructeur) { create(:instructeur) }
      let(:gi) { create(:groupe_instructeur, instructeurs: [instructeur]) }
      let(:procedure) { create(:procedure, types_de_champ_private: [{ type: :repetition, children: [{ libelle: 'Nom' }] }], groupe_instructeurs: [gi]) }
      let(:dossier) { create(:dossier, :en_instruction, procedure:) }
      let(:repetition) { dossier.project_champs_private.find(&:repetition?) }
      before { sign_in instructeur.user }

      it 'works' do
        post :add, params: { dossier_id: dossier, stable_id: repetition.stable_id }, format: :turbo_stream
        expect(response).not_to have_http_status(:not_found)
      end
    end
  end

  describe '#remove' do
    let(:row) { dossier.champs.find(&:row?) }

    subject { delete :remove, params: { dossier_id: dossier, stable_id: repetition.stable_id, row_id: row.row_id }, format: :turbo_stream }

    context 'removes repetition' do
      it { expect { subject }.not_to change { dossier.reload.champs.size } }
      it { expect { subject }.to change { dossier.reload; dossier.project_champs_public.find(&:repetition?).row_ids.size }.from(1).to(0) }
      it { expect { subject }.to change { row.reload.discarded_at }.from(nil).to(Time) }
      it { expect { subject }.to change { dossier.reload.last_champ_updated_at } }
    end
  end

  describe '#add' do
    subject { post :add, params: { dossier_id: dossier, stable_id: repetition.stable_id }, format: :turbo_stream }

    context 'add repetition' do
      it { expect { subject }.to change { dossier.reload.champs.size } }
      it { expect { subject }.to change { dossier.reload.last_champ_updated_at } }
    end
  end
end
