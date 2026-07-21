# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::LabelImprover do
  let(:schema) do
    [
      { 'stable_id' => 1, 'type' => 'text', 'libelle' => 'LIBELLE 1' },
      { 'stable_id' => 2, 'type' => 'text', 'libelle' => 'Ancien libellé' },
      { 'stable_id' => 3, 'type' => 'text', 'libelle' => 'Titre' },
    ]
  end
  let(:usage) { double() }
  let(:procedure) { create('procedure', description: 'Test description', libelle: 'Test libelle', zones: [], service: nil) }
  let(:revision) { double('revision', schema_to_llm: schema, procedure_id: 123, types_de_champ: [], procedure:) }
  let(:suggestion) { double('suggestion', procedure_revision: revision, rule: LLMRuleSuggestion.rules.fetch(:improve_label)) }
  before do
    allow(usage).to receive(:with_indifferent_access).and_return({
      prompt_tokens: 100,
      completion_tokens: 200,
      total_tokens: 300,
    }.with_indifferent_access)
  end
  describe '#generate_for' do
    it 'aggregates tool calls into normalized items (no dedup, ignore unrelated tools)' do
      tool_calls = [
        { name: 'improve_label', arguments: { 'update' => { 'stable_id' => 1, 'libelle' => 'Libellé 1', 'description' => 'bim', 'position' => 1 }, 'justification' => 'clarity' } },
        { name: 'improve_label', arguments: { 'update' => { 'stable_id' => 2, 'libelle' => 'Libellé amélioré', 'description' => 'bam', 'position' => 2 } } },
        # unrelated tool must be ignored
        { name: 'other_tool', arguments: { 'x' => 1 } },
      ]

      runner = double()
      allow(runner).to receive(:call).with(anything).and_return([tool_calls, usage])
      allow_any_instance_of(LLM::LabelImprover).to receive(:filter_invalid_llm_result).with(anything, anything, anything, anything).and_return(false)
      service = described_class.new(runner: runner)
      tool_calls, token_usage = service.generate_for(suggestion)

      expect(tool_calls.size).to eq(2)
      payloads = tool_calls.map { |i| i[:payload] }
      expect(payloads).to include({ 'stable_id' => 1, 'libelle' => 'Libellé 1', 'description' => 'bim', 'position' => 1 })
      expect(payloads).to include({ 'stable_id' => 2, 'libelle' => 'Libellé amélioré', 'description' => 'bam', 'position' => 2 })

      expect(tool_calls.first).to include(op_kind: 'update')
      expect(tool_calls.find { |i| i[:stable_id] == 1 }[:justification]).to eq('clarity')
    end
  end

  describe '#sanitize_schema_for_prompt' do
    it 'removes dangerous characters from libelle and description fields' do
      dangerous_schema = [
        { 'stable_id' => 1, 'libelle' => 'Test<script>alert("xss")</script>', 'description' => 'Desc with {brackets} and [arrays]' },
        { 'stable_id' => 2, 'libelle' => 'Normal text', 'description' => nil },
        { 'stable_id' => 3, 'libelle' => 'Text with control chars: ' + "\x00\x01\x1F", 'description' => 'Valid desc' },
      ]

      service = described_class.new
      result = service.send(:sanitize_schema_for_prompt, dangerous_schema)

      expect(result[0]['libelle']).to eq('Testscriptalert("xss")/script')
      expect(result[0]['description']).to eq('Desc with brackets and arrays')
      expect(result[1]['libelle']).to eq('Normal text')
      expect(result[1]['description']).to be_nil
      expect(result[2]['libelle']).to eq('Text with control chars:')
      expect(result[2]['description']).to eq('Valid desc')
    end

    it 'sanitizes choices arrays' do
      schema_with_choices = [
        { 'stable_id' => 1, 'choices' => ['Option <b>1</b>', 'Option {2}', 'Normal option'] },
      ]

      service = described_class.new
      result = service.send(:sanitize_schema_for_prompt, schema_with_choices)
      expect(result[0]['choices']).to eq(['Option b1/b', 'Option 2', 'Normal option'])
    end

    it 'preserves non-string fields unchanged' do
      schema = [
        { 'stable_id' => 123, 'type' => 'text', 'mandatory' => true, 'position' => 1 },
      ]

      service = described_class.new
      result = service.send(:sanitize_schema_for_prompt, schema)

      expect(result[0]['stable_id']).to eq(123)
      expect(result[0]['type']).to eq('text')
      expect(result[0]['mandatory']).to eq(true)
      expect(result[0]['position']).to eq(1)
    end

    it 'returns schema unchanged if not an array' do
      service = described_class.new
      expect(service.send(:sanitize_schema_for_prompt, 'not an array')).to eq('not an array')
      expect(service.send(:sanitize_schema_for_prompt, {})).to eq({})
    end
  end

  describe '#filter_invalid_llm_result' do
    it 'returns true for invalid results' do
      service = described_class.new
      tdc_index = double()
      allow(tdc_index).to receive(:key?).with(123).and_return(true)
      allow(tdc_index).to receive(:[]).with(123).and_return(double(libelle: "ancien", "description": "ancien"))

      # Invalid: stable_id is nil
      expect(service.send(:filter_invalid_llm_result, nil, 'libelle', 'description', tdc_index)).to be true
      # Invalid: both libelle and description are blank (no change at all)
      expect(service.send(:filter_invalid_llm_result, 123, '', '', tdc_index)).to be true
      expect(service.send(:filter_invalid_llm_result, 123, nil, nil, tdc_index)).to be true
      expect(service.send(:filter_invalid_llm_result, 123, '   ', '   ', tdc_index)).to be true
    end

    it 'returns false for valid results' do
      service = described_class.new
      tdc_index = double()
      allow(tdc_index).to receive(:key?).with(123).and_return(true)
      allow(tdc_index).to receive(:[]).with(123).and_return(double(libelle: "ancien", "description": "ancien"))

      # Valid: libelle is present
      expect(service.send(:filter_invalid_llm_result, 123, 'valid libelle', 'valid description', tdc_index)).to be false
      expect(service.send(:filter_invalid_llm_result, 123, 'libelle', '', tdc_index)).to be false

      # Valid: libelle is empty but description is present (changing only description)
      expect(service.send(:filter_invalid_llm_result, 123, '', 'description', tdc_index)).to be false
      expect(service.send(:filter_invalid_llm_result, 123, nil, 'description', tdc_index)).to be false
    end
  end

  describe '#create_batches_for_suggestion (private)' do
    let(:service) { described_class.new }

    context 'when schema has fewer than 50 fields' do
      it 'returns single batch' do
        schema = Array.new(30) { |i| { stable_id: i, type: 'text' } }

        batches = service.send(:create_batches_for_suggestion, schema, suggestion)

        expect(batches.size).to eq(1)
        expect(batches.first.size).to eq(30)
      end
    end

    context 'when schema has more than 50 fields without sections' do
      it 'splits into chunks of 50' do
        schema = Array.new(51) { |i| { stable_id: i, type: 'text' } }

        batches = service.send(:create_batches_for_suggestion, schema, suggestion)

        expect(batches.size).to eq(2)
        expect(batches[0].size).to eq(50)
        expect(batches[1].size).to eq(1)
      end
    end

    context 'when schema has level 1 sections' do
      it 'splits by section boundaries' do
        schema = [
          { stable_id: 1, type: 'header_section', header_section_level: 1 },
          *Array.new(30) { |i| { stable_id: i + 2, type: 'text' } },
          { stable_id: 100, type: 'header_section', header_section_level: 1 },
          *Array.new(30) { |i| { stable_id: i + 102, type: 'text' } },
        ]

        batches = service.send(:create_batches_for_suggestion, schema, suggestion)

        expect(batches.size).to eq(2)
        expect(batches[0].size).to eq(31) # section + 30 fields
        expect(batches[1].size).to eq(31)
      end
    end

    context 'when small sections can be merged' do
      it 'merges sections under 50 fields total' do
        schema = [
          { stable_id: 1, type: 'header_section', header_section_level: 1 },
          *Array.new(10) { |i| { stable_id: i + 2, type: 'text' } },
          { stable_id: 100, type: 'header_section', header_section_level: 1 },
          *Array.new(15) { |i| { stable_id: i + 102, type: 'text' } },
        ]

        batches = service.send(:create_batches_for_suggestion, schema, suggestion)

        expect(batches.size).to eq(1)
        expect(batches.first.size).to eq(27) # 2 headers + 25 fields
      end
    end

    context 'when a section exceeds 50 fields' do
      it 'recursively splits by deeper section levels' do
        schema = [
          { stable_id: 1, type: 'header_section', header_section_level: 1 },
          { stable_id: 2, type: 'header_section', header_section_level: 2 },
          *Array.new(30) { |i| { stable_id: i + 3, type: 'text' } },
          { stable_id: 200, type: 'header_section', header_section_level: 2 },
          *Array.new(30) { |i| { stable_id: i + 203, type: 'text' } },
        ]

        batches = service.send(:create_batches_for_suggestion, schema, suggestion)

        expect(batches.size).to eq(2)
        expect(batches[0].size).to eq(32) # h1 + h2 + 30 fields
        expect(batches[1].size).to eq(31) # h2 + 30 fields
      end
    end

    context 'when section is too large even without subsections' do
      it 'splits into chunks of 50' do
        schema = [
          { stable_id: 1, type: 'header_section', header_section_level: 1 },
          *Array.new(51) { |i| { stable_id: i + 2, type: 'text' } },
        ]

        batches = service.send(:create_batches_for_suggestion, schema, suggestion)

        expect(batches.size).to eq(2)
        expect(batches[0].size).to eq(50)
        expect(batches[1].size).to eq(2)
      end
    end
  end
end
