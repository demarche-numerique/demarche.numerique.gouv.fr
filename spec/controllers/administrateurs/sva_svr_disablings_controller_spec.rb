# frozen_string_literal: true

describe Administrateurs::SVASVRDisablingsController, type: :controller do
  before_all { seed "cases/sva" }

  let(:admin) { administrateurs.default }
  let(:procedure) { procedures.sva }

  before { sign_in(admin.user) }

  describe '#create' do
    subject { post :create, params: { procedure_id: procedure.id } }

    context 'avec un dossier en instruction, sans la case cochée' do
      let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now.to_date) }

      it 'redemande confirmation' do
        subject

        expect(response).to redirect_to(new_admin_procedure_sva_svr_disabling_path(procedure))
        expect(procedure.reload.sva_svr_disabled?).to be false
      end
    end

    context 'sur une démarche close portant une règle active' do
      let(:procedure) { procedures.close }

      before { procedure.update_column(:sva_svr, SVASVRConfiguration.new(decision: :sva).attributes) }

      it 'désactive' do
        subject

        expect(procedure.reload.sva_svr_disabled?).to be true
      end
    end

    context 'sur un brouillon ayant choisi une règle' do
      let(:procedure) { procedures.brouillon }

      before { procedure.update_column(:sva_svr, SVASVRConfiguration.new(decision: :sva).attributes) }

      it 'ne grave pas de disabled_at' do
        subject

        expect(response).to redirect_to(edit_admin_procedure_sva_svr_path(procedure))
        expect(procedure.reload.sva_svr_disabled?).to be false
      end
    end
  end
end
