# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::ImproveTypesItemComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: "Email du contact", stable_id: 10 }]) }
  let(:revision) { procedure.draft_revision }
  let(:schema_hash) { Digest::SHA256.hexdigest(revision.schema_to_llm.to_json) }
  let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision: revision, rule: 'improve_types', schema_hash:, state: 'completed') }

  describe '.step_title' do
    it 'returns the correct title' do
      expect(described_class.step_title).to eq("Bonne utilisation des types de champs")
    end
  end

  describe 'rendering via SuggestionFormComponent' do
    subject { render_inline(LLM::SuggestionFormComponent.new(llm_rule_suggestion:)) }

    context 'with type change update' do
      before do
        create(:llm_rule_suggestion_item,
          llm_rule_suggestion:,
          op_kind: 'update',
          stable_id: 10,
          payload: { 'stable_id' => 10, 'type_champ' => 'email' },
          justification: 'Validation automatique du format email')
      end

      it 'renders the type transition and field label' do
        expect(subject).to have_text("Email du contact")
        expect(subject).to have_text("Validation automatique du format email")
        # Check that both old and new types are displayed
        expect(subject).to have_css('.fr-badge', text: "Texte court")
        expect(subject).to have_css('.fr-badge.fr-badge--green-emeraude', text: "Adresse électronique")
      end
    end

    context 'with formatted type and options' do
      before do
        create(:llm_rule_suggestion_item,
          llm_rule_suggestion:,
          op_kind: 'update',
          stable_id: 10,
          payload: {
            'stable_id' => 10,
            'type_champ' => 'formatted',
            'options' => {
              'letters_accepted' => false,
              'numbers_accepted' => true,
              'special_characters_accepted' => false,
              'min_character_length' => 5,
              'max_character_length' => 5,
            },
          },
          justification: 'Code postal avec validation')
      end

      it 'renders the options summary' do
        expect(subject).to have_css('.fr-badge.fr-badge--green-emeraude', text: "Champ formaté")
        expect(subject).to have_text("chiffres")
        expect(subject).to have_text("5-5 caractères")
      end
    end

    context 'with integer_number type and options' do
      before do
        create(:llm_rule_suggestion_item,
          llm_rule_suggestion:,
          op_kind: 'update',
          stable_id: 10,
          payload: {
            'stable_id' => 10,
            'type_champ' => 'integer_number',
            'options' => {
              'positive_number' => true,
              'min_number' => 0,
              'max_number' => 100,
            },
          },
          justification: 'Pourcentage')
      end

      it 'renders the number options summary' do
        expect(subject).to have_css('.fr-badge.fr-badge--green-emeraude', text: "Nombre entier")
        expect(subject).to have_text("positif")
        expect(subject).to have_text("entre 0 et 100")
      end
    end
  end
end
