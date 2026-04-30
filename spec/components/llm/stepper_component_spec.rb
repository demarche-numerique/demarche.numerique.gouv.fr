# frozen_string_literal: true

RSpec.describe LLM::StepperComponent, type: :component do
  let(:procedure) { create(:procedure) }
  let(:last_refresh) { Time.zone.local(2025, 10, 13, 14, 40) }
  let(:llm_rule_suggestion) do
    create(:llm_rule_suggestion,
      procedure_revision: procedure.draft_revision,
      rule: rule,
      schema_hash: 'schema-hash',
      state: 'completed').tap { _1.update!(created_at: last_refresh) }
  end
  let(:step_component) { LLM::SuggestionFormComponent.new(llm_rule_suggestion:) }
  subject(:rendered_component) { render_inline(described_class.new(step_component:)) }

  context 'with the label improvement rule' do
    let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }
    it 'shows the first step and the correct next step' do
      expect(rendered_component.css('.fr-stepper__state').text).to eq('Étape 1 sur 4')
      expect(rendered_component.css('.fr-stepper__title').text).to include("Libellés et descriptions des champs")
      expect(rendered_component.css('.fr-stepper__details').text).to include("Structure du formulaire")
    end
  end

  context 'with the last rule' do
    let(:rule) { LLMRuleSuggestion.rules.fetch(LLM::Rule::SEQUENCE.last) }
    it 'marks the fourth step and shows no further step' do
      expect(rendered_component.css('.fr-stepper__state').text).to eq('Étape 4 sur 4')
      expect(rendered_component.css('.fr-stepper__title').text).to include("Demande unique d’information")
    end
  end
end
