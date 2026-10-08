# frozen_string_literal: true

describe ProcedureSVASVRConcern do
  before_all { seed "cases/sva" }

  describe 'une règle désactivée' do
    let(:procedure) { procedures.sva }

    before { procedure.update_column(:sva_svr, procedure.sva_svr.merge('disabled_at' => Time.current.iso8601)) }

    it 'garde ses réglages malgré la désactivation' do
      procedure.update_column(:sva_svr, procedure.sva_svr.merge('period' => 7))

      configuration = procedure.sva_svr_configuration

      expect(configuration.decision).to eq('sva')
      expect(configuration.period).to eq(7)
    end
  end

  describe '#sva_svr_pending_dossiers' do
    let(:procedure) { procedures.sva }

    let!(:en_instruction) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now.to_date) }
    let!(:en_attente_de_correction) { create(:dossier, :en_construction, :with_individual, procedure:, sva_svr_decision_on: 3.days.from_now.to_date) }
    let!(:tranche) { create(:dossier, :accepte, :with_individual, procedure:, sva_svr_decision_on: 1.day.ago.to_date, sva_svr_decision_triggered_at: 1.day.ago) }
    let!(:sans_date) { create(:dossier, :en_instruction, :with_individual, procedure:) }

    it 'ne retient que les dossiers en cours portant une date' do
      expect(procedure.sva_svr_pending_dossiers).to contain_exactly(en_instruction, en_attente_de_correction)
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
