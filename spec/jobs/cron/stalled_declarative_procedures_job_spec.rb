# frozen_string_literal: true

RSpec.describe Cron::StalledDeclarativeProceduresJob, type: :job do
  describe "perform" do
    let(:state) { nil }
    let(:procedure) { create(:procedure, :published, :for_individual, :with_instructeur, declarative_with_state: state) }
    let!(:brouillon) { create(:dossier, :brouillon, procedure:) }
    let!(:en_construction) { create(:dossier, :en_construction, :with_individual, procedure:) }
    let!(:en_construction_triggered) { create(:dossier, :en_construction, :with_individual, procedure:, declarative_triggered_at: 1.minute.ago) }
    let!(:en_instruction) { create(:dossier, :en_instruction, :with_individual, procedure:) }

    subject(:perform_job) do
      described_class.perform_now
    end

    context "declarative en instruction" do
      let(:state) { Dossier.states.fetch(:en_instruction) }

      it {
        perform_job
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued.with(brouillon)
        expect(ProcessStalledDeclarativeDossierJob).to have_been_enqueued.with(en_construction)
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued.with(en_construction_triggered)
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued.with(en_instruction)
      }
    end

    context "declarative accepte" do
      let(:state) { Dossier.states.fetch(:accepte) }

      it {
        perform_job
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued.with(brouillon)
        expect(ProcessStalledDeclarativeDossierJob).to have_been_enqueued.with(en_construction)
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued.with(en_construction_triggered)
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued.with(en_instruction)
      }
    end

    context "not declarative" do
      let(:state) { nil }

      it {
        perform_job
        expect(ProcessStalledDeclarativeDossierJob).not_to have_been_enqueued
      }
    end
  end
end
