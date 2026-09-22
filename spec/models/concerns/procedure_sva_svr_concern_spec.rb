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

  describe 'immuabilité sur une démarche publiée' do
    let(:procedure) { procedures.sva }

    def disable!(p) = p.sva_svr = p.sva_svr.merge('disabled_at' => Time.current.iso8601)

    it 'autorise la désactivation' do
      disable!(procedure)

      expect(procedure).to be_valid
    end

    it 'refuse une modification du délai en même temps que la désactivation' do
      procedure.sva_svr = procedure.sva_svr.merge('disabled_at' => Time.current.iso8601, 'period' => 12)

      expect(procedure).not_to be_valid
      expect(procedure.errors).to be_of_kind(:sva_svr, :immutable)
    end

    it 'refuse une modification seule' do
      procedure.sva_svr = procedure.sva_svr.merge('period' => 12)

      expect(procedure).not_to be_valid
      expect(procedure.errors).to be_of_kind(:sva_svr, :immutable)
    end

    context 'quand la règle est déjà désactivée' do
      before do
        disable!(procedure)
        procedure.save!
      end

      it 'refuse la réactivation' do
        procedure.sva_svr = procedure.sva_svr.except('disabled_at')

        expect(procedure).not_to be_valid
        expect(procedure.errors).to be_of_kind(:sva_svr, :definitive)
      end

      it 'refuse un changement de sens' do
        procedure.sva_svr = procedure.sva_svr.merge('decision' => 'svr')

        expect(procedure).not_to be_valid
        expect(procedure.errors).to be_of_kind(:sva_svr, :definitive)
      end
    end
  end
end
