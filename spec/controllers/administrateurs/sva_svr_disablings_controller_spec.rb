# frozen_string_literal: true

describe Administrateurs::SVASVRDisablingsController, type: :controller do
  before_all { seed "cases/sva" }

  let(:admin) { administrateurs.default }
  let(:procedure) { procedures.sva }

  before { sign_in(admin.user) }

  describe '#new' do
    render_views

    let!(:en_attente_de_correction) { create(:dossier, :en_construction, :with_individual, procedure:, sva_svr_decision_on: 3.days.from_now.to_date) }
    let!(:en_instruction) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now.to_date) }

    it 'compte les deux dossiers mais n’annonce que l’échéance du dossier en instruction' do
      get :new, params: { procedure_id: procedure.id }

      expect(response.body).to include('Les <strong>2 dossiers déjà déposés et encore en cours</strong>')
      expect(response.body).to include(I18n.l(10.days.from_now.to_date, format: :long))
      expect(response.body).not_to include(I18n.l(3.days.from_now.to_date, format: :long))
    end
  end

  describe '#create' do
    subject { post :create, params: { procedure_id: procedure.id } }

    context 'avec un dossier en instruction, sans la case cochée' do
      let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now.to_date) }

      it 'redemande confirmation' do
        subject

        expect(response).to redirect_to(new_admin_procedure_sva_svr_disabling_path(procedure))
        expect(procedure.reload.sva_svr_rule_disabled?).to be false
      end
    end

    context 'sur une démarche close portant une règle active' do
      let(:procedure) { procedures.close }

      before { procedure.update_column(:sva_svr, SVASVRConfiguration.new(decision: :sva).attributes) }

      it 'désactive' do
        subject

        expect(procedure.reload.sva_svr_rule_disabled?).to be true
      end
    end

    context 'sur un brouillon ayant choisi une règle' do
      let(:procedure) { procedures.brouillon }

      before { procedure.update_column(:sva_svr, SVASVRConfiguration.new(decision: :sva).attributes) }

      it 'ne grave pas de disabled_at' do
        subject

        expect(response).to redirect_to(edit_admin_procedure_sva_svr_path(procedure))
        expect(procedure.reload.sva_svr_rule_disabled?).to be false
      end
    end
  end
end
