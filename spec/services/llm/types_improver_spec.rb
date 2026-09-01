# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::TypesImprover do
  let(:schema) do
    [
      { 'stable_id' => 1, 'type' => 'text', 'libelle' => 'Adresse email du contact' },
      { 'stable_id' => 2, 'type' => 'text', 'libelle' => 'Numéro de téléphone' },
      { 'stable_id' => 3, 'type' => 'text', 'libelle' => 'Adresse postale' },
    ]
  end
  let(:rule) { 'improve_types' }
  let(:usage) { double() }
  let(:procedure) { double('procedure', libelle: 'Test Procedure', description: 'Test description', for_individual: false) }
  let(:type_de_champs) do
    [
      double('tdc1', stable_id: 1, type_champ: 'text'),
      double('tdc2', stable_id: 2, type_champ: 'text'),
      double('tdc3', stable_id: 3, type_champ: 'text'),
    ]
  end
  let(:revision) { double('revision', schema_to_llm: schema, procedure_id: 1, type_de_champs:, procedure:) }
  let(:suggestion) { double('suggestion', procedure_revision: revision, rule:) }

  before do
    allow(usage).to receive(:with_indifferent_access).and_return({
      prompt_tokens: 100,
      completion_tokens: 200,
      total_tokens: 300,
    }.with_indifferent_access)
  end

  describe '#generate_for' do
    it 'normalises update tool calls for type changes' do
      calls = [
        {
          name: rule,
          arguments: {
            'update' => { 'stable_id' => 1, 'type_champ' => 'email' },
            'justification' => 'Le libellé indique une adresse email',
          },
        },
        {
          name: rule,
          arguments: {
            'update' => { 'stable_id' => 2, 'type_champ' => 'phone' },
            'justification' => 'Le libellé indique un numéro de téléphone',
          },
        },
      ]

      runner = double()
      allow(runner).to receive(:call).with(anything).and_return([calls, usage])
      service = described_class.new(runner:)

      tool_calls, _token_usage = service.generate_for(suggestion)

      expect(tool_calls.size).to eq(2)
      expect(tool_calls.first).to include(op_kind: 'update', stable_id: 1)
      expect(tool_calls.first[:payload]).to include('type_champ' => 'email')
      expect(tool_calls.second).to include(op_kind: 'update', stable_id: 2)
      expect(tool_calls.second[:payload]).to include('type_champ' => 'phone')
    end

    it 'filters update when type_champ unchanged' do
      calls = [
        {
          name: rule,
          arguments: {
            'update' => { 'stable_id' => 1, 'type_champ' => 'text' }, # same as original
            'justification' => 'Test',
          },
        },
      ]

      runner = double()
      allow(runner).to receive(:call).with(anything).and_return([calls, usage])
      service = described_class.new(runner:)

      tool_calls, _token_usage = service.generate_for(suggestion)

      expect(tool_calls).to be_empty
    end

    it 'filters invalid type_champ values' do
      calls = [
        {
          name: rule,
          arguments: {
            'update' => { 'stable_id' => 1, 'type_champ' => 'invalid_type' },
            'justification' => 'Test',
          },
        },
      ]

      runner = double()
      allow(runner).to receive(:call).with(anything).and_return([calls, usage])
      service = described_class.new(runner:)

      tool_calls, _token_usage = service.generate_for(suggestion)

      expect(tool_calls).to be_empty
    end

    it 'ignores unrelated tool calls' do
      calls = [
        { name: 'other_tool', arguments: { 'x' => 1 } },
      ]

      runner = double()
      allow(runner).to receive(:call).with(anything).and_return([calls, usage])
      service = described_class.new(runner:)

      tool_calls, _token_usage = service.generate_for(suggestion)

      expect(tool_calls).to be_empty
    end

    context 'with options' do
      it 'includes valid options in payload for formatted type' do
        calls = [
          {
            name: rule,
            arguments: {
              'update' => {
                'stable_id' => 1,
                'type_champ' => 'formatted',
                'options' => {
                  'letters_accepted' => false,
                  'numbers_accepted' => true,
                  'special_characters_accepted' => false,
                  'min_character_length' => 5,
                  'max_character_length' => 5,
                },
              },
              'justification' => 'Code postal',
            },
          },
        ]

        runner = double()
        allow(runner).to receive(:call).with(anything).and_return([calls, usage])
        service = described_class.new(runner:)

        tool_calls, _token_usage = service.generate_for(suggestion)

        expect(tool_calls.size).to eq(1)
        expect(tool_calls.first[:payload]).to include('type_champ' => 'formatted')
        expect(tool_calls.first[:payload]['options']).to include(
          'letters_accepted' => false,
          'numbers_accepted' => true,
          'min_character_length' => 5
        )
      end

      it 'filters out invalid options for the type' do
        calls = [
          {
            name: rule,
            arguments: {
              'update' => {
                'stable_id' => 1,
                'type_champ' => 'email',
                'options' => {
                  'letters_accepted' => true, # invalid for email
                  'invalid_option' => 'test',
                },
              },
              'justification' => 'Test',
            },
          },
        ]

        runner = double()
        allow(runner).to receive(:call).with(anything).and_return([calls, usage])
        service = described_class.new(runner:)

        tool_calls, _token_usage = service.generate_for(suggestion)

        expect(tool_calls.size).to eq(1)
        expect(tool_calls.first[:payload]).not_to have_key('options')
      end

      it 'includes valid options for integer_number type' do
        calls = [
          {
            name: rule,
            arguments: {
              'update' => {
                'stable_id' => 1,
                'type_champ' => 'integer_number',
                'options' => {
                  'positive_number' => true,
                  'min_number' => 0,
                  'max_number' => 100,
                },
              },
              'justification' => 'Pourcentage',
            },
          },
        ]

        runner = double()
        allow(runner).to receive(:call).with(anything).and_return([calls, usage])
        service = described_class.new(runner:)

        tool_calls, _token_usage = service.generate_for(suggestion)

        expect(tool_calls.size).to eq(1)
        expect(tool_calls.first[:payload]['options']).to include(
          'positive_number' => true,
          'min_number' => 0,
          'max_number' => 100
        )
      end
    end

    context 'with nature' do
      let(:types_de_champ) do
        [
          double('tdc4', stable_id: 4, type_champ: 'piece_justificative', nature: 'non_specifie'),
          double('tdc5', stable_id: 5, type_champ: 'piece_justificative', nature: 'rib'),
        ]
      end

      def tool_calls_for(update)
        calls = [{ name: rule, arguments: { 'update' => update, 'justification' => 'Test' } }]
        runner = double()
        allow(runner).to receive(:call).with(anything).and_return([calls, usage])

        described_class.new(runner:).generate_for(suggestion).first
      end

      it 'keeps a nature change on an unchanged piece_justificative' do
        tool_calls = tool_calls_for({ 'stable_id' => 4, 'type_champ' => 'piece_justificative', 'nature' => 'justificatif_domicile' })

        expect(tool_calls.size).to eq(1)
        expect(tool_calls.first[:payload]).to include(
          'stable_id' => 4,
          'type_champ' => 'piece_justificative',
          'nature' => 'justificatif_domicile'
        )
      end

      it 'filters update when nature unchanged' do
        tool_calls = tool_calls_for({ 'stable_id' => 5, 'type_champ' => 'piece_justificative', 'nature' => 'rib' })

        expect(tool_calls).to be_empty
      end

      it 'filters invalid nature values' do
        tool_calls = tool_calls_for({ 'stable_id' => 4, 'type_champ' => 'piece_justificative', 'nature' => 'invalid_nature' })

        expect(tool_calls).to be_empty
      end

      it 'filters nature on a type that is not a piece_justificative' do
        tool_calls = tool_calls_for({ 'stable_id' => 1, 'type_champ' => 'email', 'nature' => 'justificatif_domicile' })

        expect(tool_calls).to be_empty
      end
    end
  end
end
