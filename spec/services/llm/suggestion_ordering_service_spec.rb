# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::SuggestionOrderingService do
  describe '.merge_suggestions_into_originals' do
    def mock_suggestion(stable_id: nil, generated_stable_id: nil, after_stable_id:, parent_stable_id: nil)
      double('Suggestion').tap do |item|
        allow(item).to receive(:is_a?).with(LLMRuleSuggestionItem).and_return(true)
        allow(item).to receive(:payload).and_return({
          'stable_id' => stable_id,
          'generated_stable_id' => generated_stable_id,
          'after_stable_id' => after_stable_id,
          'parent_stable_id' => parent_stable_id,
        })
      end
    end

    # a header section when given children
    def mock_original(stable_id, children: nil)
      double("Original #{stable_id}").tap do |rtdc|
        allow(rtdc).to receive(:is_a?).with(LLMRuleSuggestionItem).and_return(false)
        allow(rtdc).to receive(:stable_id).and_return(stable_id)
        allow(rtdc).to receive(:header_section?).and_return(!children.nil?)
        allow(rtdc).to receive(:children).and_return(children.to_a)
      end
    end

    def stable_ids(result)
      result.map { |item| described_class.stable_id_of(item) }
    end

    def mock_llm_rule_suggestion(suggestions, originals)
      double('LLMRuleSuggestion').tap do |llm_rule_suggestion|
        allow(llm_rule_suggestion).to receive(:llm_rule_suggestion_items).and_return(double(to_a: suggestions))
        revision = double('ProcedureRevision')
        allow(revision).to receive(:public_type_de_champs).and_return(originals)
        allow(llm_rule_suggestion).to receive(:procedure_revision).and_return(revision)
      end
    end

    context 'without suggestions' do
      it 'returns originals in order' do
        originals = [mock_original(1), mock_original(2), mock_original(3)]
        llm_rule_suggestion = mock_llm_rule_suggestion([], originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([1, 2, 3])
      end
    end

    context 'with add operations' do
      it 'inserts header at beginning' do
        originals = [mock_original(1), mock_original(2), mock_original(3)]
        suggestions = [mock_suggestion(generated_stable_id: -1, after_stable_id: nil)]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([-1, 1, 2, 3])
      end

      it 'inserts header in middle' do
        originals = [mock_original(1), mock_original(2), mock_original(3)]
        suggestions = [mock_suggestion(generated_stable_id: -1, after_stable_id: 2)]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([1, 2, -1, 3])
      end

      it 'inserts multiple headers' do
        originals = [mock_original(1), mock_original(2)]
        suggestions = [
          mock_suggestion(generated_stable_id: -1, after_stable_id: nil),
          mock_suggestion(generated_stable_id: -2, after_stable_id: 1),
        ]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([-1, 1, -2, 2])
      end

      it 'inserts a header placed first of a section right after it, an added one included' do
        originals = [mock_original(1), mock_original(2)]
        suggestions = [
          mock_suggestion(generated_stable_id: -1, after_stable_id: nil, parent_stable_id: 1),
          mock_suggestion(generated_stable_id: -2, after_stable_id: nil, parent_stable_id: -1),
        ]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([1, -1, -2, 2])
      end

      it 'inserts a header placed after a section after what the section holds, one placed first of it right after it' do
        originals = [mock_original(1, children: [mock_original(2), mock_original(3, children: [mock_original(4)])]), mock_original(5)]
        suggestions = [
          mock_suggestion(generated_stable_id: -1, after_stable_id: 1),
          mock_suggestion(generated_stable_id: -2, after_stable_id: nil, parent_stable_id: 1),
          mock_suggestion(generated_stable_id: -3, after_stable_id: 3),
          mock_suggestion(generated_stable_id: -4, after_stable_id: -3),
        ]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([1, -2, 2, 3, 4, -3, -4, -1, 5])
      end

      it 'does not loop on a header anchored on itself' do
        originals = [mock_original(1), mock_original(2)]
        suggestions = [
          mock_suggestion(generated_stable_id: 1, after_stable_id: 1),
          mock_suggestion(generated_stable_id: -1, after_stable_id: 2),
        ]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([1, 1, 2, -1])
      end
    end

    context 'with the suggestions applied' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { libelle: 'a', stable_id: 1 },
          { type: :header_section, libelle: 's', stable_id: 2, children: [{ libelle: 'b', stable_id: 3 }, { libelle: 'c', stable_id: 4 }] },
          { libelle: 'd', stable_id: 5 },
          { type: :repetition, libelle: 'r', stable_id: 6, children: [{ libelle: 'r1', stable_id: 7 }] },
        ])
      end
      let(:draft) { procedure.draft_revision }
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision: draft, rule: LLMRuleSuggestion.rules.fetch('improve_structure')) }

      def add(libelle, generated_stable_id, after_stable_id: nil, parent_stable_id: nil)
        payload = { 'generated_stable_id' => generated_stable_id, 'after_stable_id' => after_stable_id, 'parent_stable_id' => parent_stable_id, 'libelle' => libelle }.compact
        create(:llm_rule_suggestion_item, llm_rule_suggestion:, verify_status: 'accepted', op_kind: 'add', payload:)
      end

      it 'shows the form in the order it takes once they are applied' do
        add('first of the form', -1)
        add('after a', -2, after_stable_id: 1)
        add('first of the one after a', -3, parent_stable_id: -2)
        add('after s', -4, after_stable_id: 2)
        add('first of s', -5, parent_stable_id: 2)
        add('after c', -6, after_stable_id: 4)
        add('after the one after s', -7, after_stable_id: -4)

        shown = described_class.ordered_structure_suggestions(llm_rule_suggestion.reload).map { it.is_a?(LLMRuleSuggestionItem) ? it.payload['libelle'] : it.libelle }
        draft.apply_llm_rule_suggestion_items(llm_rule_suggestion.changes_to_apply)

        expect(llm_rule_suggestion.llm_rule_suggestion_items.reload).to all(be_accepted)
        expect(shown).to eq(draft.reload.public_root_type_de_champs.map(&:libelle))
        expect(shown).to eq(['first of the form', 'a', 'after a', 'first of the one after a', 's', 'first of s', 'b', 'c', 'after c', 'after s', 'after the one after s', 'd', 'r'])
      end
    end

    context 'with cycle detection' do
      it 'raises error when duplicate after_stable_id detected' do
        originals = [mock_original(1), mock_original(2)]
        suggestions = [
          mock_suggestion(generated_stable_id: -1, after_stable_id: 1),
          mock_suggestion(generated_stable_id: -2, after_stable_id: 1),
        ]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        expect {
          described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        }.to raise_error(/Cycle détecté/)
      end

      it 'takes after a section and first of it for two places' do
        originals = [mock_original(1, children: [mock_original(2)])]
        suggestions = [
          mock_suggestion(generated_stable_id: -1, after_stable_id: 1),
          mock_suggestion(generated_stable_id: -2, after_stable_id: nil, parent_stable_id: 1),
        ]
        llm_rule_suggestion = mock_llm_rule_suggestion(suggestions, originals)

        result = described_class.merge_suggestions_into_originals(llm_rule_suggestion)
        expect(stable_ids(result)).to eq([1, -2, 2, -1])
      end
    end
  end

  describe '.stable_id_of' do
    it 'returns stable_id for update item' do
      item = mock_suggestion(stable_id: 123, after_stable_id: nil)
      expect(described_class.stable_id_of(item)).to eq(123)
    end

    it 'returns generated_stable_id for add item' do
      item = mock_suggestion(generated_stable_id: -1, after_stable_id: nil)
      expect(described_class.stable_id_of(item)).to eq(-1)
    end

    it 'returns stable_id for original rtdc' do
      rtdc = mock_original(456)
      expect(described_class.stable_id_of(rtdc)).to eq(456)
    end

    def mock_suggestion(stable_id: nil, generated_stable_id: nil, after_stable_id:)
      double('Suggestion').tap do |item|
        allow(item).to receive(:is_a?).with(LLMRuleSuggestionItem).and_return(true)
        allow(item).to receive(:payload).and_return({
          'stable_id' => stable_id,
          'generated_stable_id' => generated_stable_id,
          'after_stable_id' => after_stable_id,
        })
      end
    end

    def mock_original(stable_id)
      double("Original #{stable_id}").tap do |rtdc|
        allow(rtdc).to receive(:is_a?).with(LLMRuleSuggestionItem).and_return(false)
        allow(rtdc).to receive(:stable_id).and_return(stable_id)
      end
    end
  end
end
