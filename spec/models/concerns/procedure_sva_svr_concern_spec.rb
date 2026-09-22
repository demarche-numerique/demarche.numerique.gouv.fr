# frozen_string_literal: true

describe ProcedureSVASVRConcern do
  before_all { seed "cases/sva" }

  describe 'une règle désactivée' do
    let(:procedure) { procedures.sva }

    before { procedure.update_column(:sva_svr, procedure.sva_svr.merge('disabled_at' => Time.current.iso8601)) }

    it 'éteint le moteur' do
      expect(procedure.sva_svr_enabled?).to be false
      expect(procedure.sva?).to be false
    end

    it 'garde la mémoire de la règle appliquée' do
      expect(procedure.sva_svr_ever_enabled?).to be true
      expect(procedure.sva_svr_decision).to eq(:sva)
      expect(procedure.sva_svr_disabled?).to be true
    end

    it 'sort du scope que parcourt le cron' do
      expect(Procedure.sva_svr).not_to include(procedure)
    end

    it 'garde ses réglages malgré la désactivation' do
      procedure.update_column(:sva_svr, procedure.sva_svr.merge('period' => 7))

      configuration = procedure.sva_svr_configuration

      expect(configuration.decision).to eq('sva')
      expect(configuration.period).to eq(7)
    end

    it 'éteint aussi svr?' do
      svr_procedure = procedures.svr
      svr_procedure.update_column(:sva_svr, svr_procedure.sva_svr.merge('disabled_at' => Time.current.iso8601))

      expect(svr_procedure.svr?).to be false
    end
  end

  describe 'une règle active' do
    let(:procedure) { procedures.sva }

    it 'reste dans le scope' do
      expect(procedure.sva_svr_enabled?).to be true
      expect(procedure.sva_svr_disabled?).to be false
      expect(Procedure.sva_svr).to include(procedure)
    end
  end
end
