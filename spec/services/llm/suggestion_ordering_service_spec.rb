# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::SuggestionOrderingService do
  describe '.merge_suggestions_into_originals' do
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

    def stable_ids(result)
      result.map { |item| described_class.stable_id_of(item) }
    end

    def mock_llm_rule_suggestion(suggestions, originals)
      double('LLMRuleSuggestion').tap do |llm_rule_suggestion|
        allow(llm_rule_suggestion).to receive(:llm_rule_suggestion_items).and_return(double(to_a: suggestions))
        revision = double('ProcedureRevision')
        allow(revision).to receive(:public_revision_types_de_champ).and_return(double(to_a: originals))
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
