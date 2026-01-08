# frozen_string_literal: true

RSpec.describe ProcessStalledDeclarativeDossierJob, type: :job do
  describe "perform" do
    let(:procedure) { create(:procedure, :published, :for_individual, :with_instructeur, declarative_with_state: state) }
    let!(:attestation_template) { create(:attestation_template, procedure:, kind: :acceptation, state: :published) }
    let(:last_operation) { dossier.dossier_operation_logs.last }

    subject(:perform_job) do
      perform_enqueued_jobs(only: AttestationPdfGenerationJob) do
        described_class.perform_now(dossier.reload)
      end
      dossier.reload
    end

    before do
      freeze_time
    end

    context 'declarative en instruction' do
      let(:state) { Dossier.states.fetch(:en_instruction) }

      context 'dossier en_construction' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }

        it {
          perform_job
          expect(dossier.state).to eq('en_instruction')
          expect(dossier.en_instruction_at).to eq(Time.current)
          expect(last_operation.operation).to eq('passer_en_instruction')
          expect(last_operation.automatic_operation?).to be_truthy
        }

        context 'dossier repasse en_construction' do
          let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, declarative_triggered_at: 1.day.ago) }

          it { expect(subject.state).to eq('en_construction') }
        end
      end

      context 'dossier already en_instruction' do
        let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, en_instruction_at: 2.days.ago) }

        it {
          perform_job
          expect(dossier.state).to eq('en_instruction')
          expect(dossier.en_instruction_at).to eq(2.days.ago)
          expect(dossier.processed_at).to be_nil
        }
      end
    end

    context "declarative accepte" do
      let(:state) { Dossier.states.fetch(:accepte) }

      context 'dossier en_construction' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }

        it {
          perform_job
          expect(dossier.state).to eq('accepte')
          expect(dossier.en_instruction_at).to eq(Time.current)
          expect(dossier.processed_at).to eq(Time.current)
          expect(dossier.attestation).to be_present
          expect(last_operation.operation).to eq('accepter')
          expect(last_operation.automatic_operation?).to be_truthy
        }
      end

      context 'dossier en_instruction' do
        let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, en_instruction_at: 2.days.ago) }

        it {
          perform_job
          expect(dossier.state).to eq('en_instruction')
          expect(dossier.en_instruction_at).to eq(2.days.ago)
          expect(dossier.processed_at).to be_nil
        }
      end

      context 'dossier brouillon' do
        let(:dossier) { create(:dossier, :brouillon) }

        it {
          perform_job
          expect(dossier.state).to eq('brouillon')
          expect(dossier.en_instruction_at).to be_nil
          expect(dossier.processed_at).to be_nil
        }
      end

      context 'for entreprise' do
        let(:procedure) { create(:procedure, :published, :with_instructeur, for_individual: false, declarative_with_state: state) }

        let(:dossier) { create(:dossier, :en_construction, :with_entreprise, procedure:, as_degraded_mode: false) }

        it { expect(subject).to be_accepte }

        context 'having etablissement in degraded_mode' do
          let(:dossier) { create(:dossier, :en_construction, :with_entreprise, procedure:, as_degraded_mode: true) }

          before do
            expect(dossier).to_not receive(:accepter_automatiquement!)
            expect(Sentry).to_not receive(:capture_exception)
          end

          it { expect(subject).to be_en_construction }
        end
      end
    end
  end
end
