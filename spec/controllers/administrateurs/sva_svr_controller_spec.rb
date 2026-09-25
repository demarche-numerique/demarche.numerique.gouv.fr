# frozen_string_literal: true

describe Administrateurs::SVASVRController, type: :controller do
  before_all { seed "cases/sva" }

  let(:admin) { administrateurs.default }
  let(:procedure) { procedures.sva }

  before { sign_in(admin.user) }

  describe '#update sur une règle déjà désactivée' do
    before { procedure.update_column(:sva_svr, procedure.disable_sva_svr) }

    it 'refuse et renvoie sur l’écran de réglage' do
      patch :update, params: { procedure_id: procedure.id, sva_svr_configuration: { decision: 'svr', period: 2, unit: 'months', resume: 'continue' } }

      expect(response).to redirect_to(edit_admin_procedure_sva_svr_path(procedure))
      expect(flash.alert).to be_present
    end
  end
end
