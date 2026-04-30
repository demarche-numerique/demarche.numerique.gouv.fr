# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::CleanerItemComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: "Commune", stable_id: 10 }]) }
  let(:revision) { procedure.draft_revision }
  let(:schema_hash) { Digest::SHA256.hexdigest(revision.schema_to_llm.to_json) }
  let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision: revision, rule: 'cleaner', schema_hash:, state: 'completed') }

  describe '.step_title' do
    it 'returns the correct title' do
      expect(described_class.step_title).to eq("Demande unique d’information")
    end
  end

  describe 'rendering via SuggestionFormComponent' do
    subject { render_inline(LLM::SuggestionFormComponent.new(llm_rule_suggestion:)) }

    context 'with destroy operation' do
      before do
        create(:llm_rule_suggestion_item,
          llm_rule_suggestion:,
          op_kind: 'destroy',
          stable_id: 10,
          payload: { 'stable_id' => 10 },
          justification: 'Le champ adresse fournit déjà cette information')
      end

      it 'renders the deletion message without badge' do
        expect(subject).to have_text("Suppression de")
        expect(subject).to have_text("Commune")
        expect(subject).to have_text("Le champ adresse fournit déjà cette information")
      end
    end
  end
end
