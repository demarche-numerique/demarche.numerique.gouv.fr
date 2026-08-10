# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::CleanerImprover do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public:, service: create(:service)) }
  let(:revision) { procedure.active_revision }
  let(:suggestion) { double('suggestion', procedure_revision: revision, rule: 'cleaner') }
  let(:usage) do
    {
      prompt_tokens: 100,
      completion_tokens: 200,
      total_tokens: 300,
    }.with_indifferent_access
  end

  describe '#generate_for' do
    let(:types_de_champ_public) do
      [
        { type: :address, libelle: 'Adresse postale' },
        { type: :text, libelle: 'Commune' },
        { type: :text, libelle: 'Code postal' },
      ]
    end

    it 'normalises destroy tool calls' do
      tdcs = revision.root_public_types_de_champ
      commune_stable_id = tdcs.find { it.libelle == 'Commune' }.stable_id

      calls = [
        {
          name: 'cleaner',
          arguments: {
            'destroy' => { 'stable_id' => commune_stable_id },
            'justification' => 'Le champ adresse fournit déjà la commune',
          },
        },
      ]

      runner = double()
      allow(runner).to receive(:call).with(anything).and_return([calls, usage])
      service = described_class.new(runner:)

      tool_calls, _token_usage = service.generate_for(suggestion)

      expect(tool_calls.size).to eq(1)
      expect(tool_calls.first).to include(op_kind: 'destroy', stable_id: commune_stable_id)
    end

    context 'when field is used as a condition source' do
      let(:source_stable_id) { 9999 }
      let(:condition) { ds_eq(champ_value(source_stable_id), constant(true)) }
      let(:types_de_champ_public) do
        [
          { type: :yes_no, libelle: 'Êtes-vous majeur ?', stable_id: source_stable_id },
          { type: :text, libelle: 'Détails', condition: },
          { type: :text, libelle: 'Autre champ' },
        ]
      end

      it 'rejects destroy suggestions for fields used in conditions' do
        calls = [
          {
            name: 'cleaner',
            arguments: {
              'destroy' => { 'stable_id' => source_stable_id },
              'justification' => 'Champ redondant',
            },
          },
        ]

        runner = double()
        allow(runner).to receive(:call).with(anything).and_return([calls, usage])
        service = described_class.new(runner:)

        tool_calls, _token_usage = service.generate_for(suggestion)

        expect(tool_calls).to be_empty
      end
    end
  end
end
