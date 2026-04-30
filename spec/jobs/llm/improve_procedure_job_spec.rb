# frozen_string_literal: true

describe LLM::ImproveProcedureJob, type: :job do
  subject(:perform) { described_class.perform_now(procedure, tunnel_id, rule, action: "nightly") }
  let(:tunnel_id) { SecureRandom.hex(3) }
  let(:rule) { LLMRuleSuggestion.rules.values.first }
  let(:procedure) { create(:procedure, :published) }

  before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }

  it 'creates suggestions and enqueues generation jobs for given rules on the draft revision' do
    expect { perform }.to change { LLMRuleSuggestion.count }.by(1)

    expect(LLM::GenerateRuleSuggestionJob).to have_been_enqueued.exactly(:once)
    expect(LLMRuleSuggestion.distinct.pluck(:procedure_revision_id)).to contain_exactly(procedure.draft_revision.id)
  end

  it 'does not duplicate suggestions when run twice' do
    perform
    clear_enqueued_jobs

    expect { perform }.not_to change { LLMRuleSuggestion.count }
    expect(LLM::GenerateRuleSuggestionJob).not_to have_been_enqueued
  end

  it 'requeues failed suggestions' do
    perform
    LLMRuleSuggestion.update_all(state: :failed)
    clear_enqueued_jobs

    described_class.perform_now(procedure, tunnel_id, rule, action: "nightly")

    expect(LLMRuleSuggestion.pluck(:state)).to all(eq('queued'))
    expect(LLM::GenerateRuleSuggestionJob).to have_been_enqueued.exactly(:once)
  end
end
