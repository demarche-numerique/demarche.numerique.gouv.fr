# frozen_string_literal: true

RSpec.describe LLM::SuggestionFormComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'Nom' }]) }
  let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }
  let(:schema_hash) { 'schema-hash' }
  let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, rule:, schema_hash:, state:) }

  subject { render_inline(described_class.new(llm_rule_suggestion: llm_rule_suggestion)) }

  describe 'rendering' do
    context 'when state is queued' do
      let(:state) { 'queued' }

      it 'shows waiting message' do
        expect(subject).to have_content("Recherche en cours")
        expect(subject).not_to have_css("button[value='Lancer la recherche de suggestions']")
      end
    end
    context 'when state is running' do
      let(:state) { 'running' }

      it 'shows waiting message' do
        expect(subject).to have_content("Recherche en cours")
        expect(subject).not_to have_css("button[value='Lancer la recherche de suggestions']")
      end
    end

    context 'when state is pending' do
      let(:state) { 'pending' }

      it 'shows status message and launch button' do
        expect(subject).to have_button("Lancer la recherche de suggestions")
      end
    end

    context 'when state is completed' do
      let(:state) { 'completed' }

      context 'when there are suggestions' do
        before do
          revision_coordinate = procedure.draft_revision.revision_types_de_champ_public.first

          create(:llm_rule_suggestion_item,
            llm_rule_suggestion:,
            stable_id: revision_coordinate.stable_id,
            payload: { 'stable_id' => revision_coordinate.stable_id, 'libelle' => 'Nom simplifié' })
        end

        it 'shows the configured title' do
          expect(subject.text).to include("Cette étape propose une mise à jour des libellés")
          expect(subject).not_to have_css("button[value='Lancer la recherche de suggestions']")
          expect(subject.text).to have_content(/1\s+suggestion/)
        end

        it 'disables submit button when no suggestions are accepted' do
          expect(subject).to have_css("input[type='submit'][disabled]")
        end

        context 'when at least one suggestion is accepted' do
          before do
            llm_rule_suggestion.llm_rule_suggestion_items.first.update(verify_status: 'accepted')
          end

          it 'enables submit button' do
            expect(subject).not_to have_css("input[type='submit'][disabled]")
          end
        end
      end

      context 'when there are no suggestions' do
        it 'shows "Poursuivre" button' do
          expect(subject).to have_button("Poursuivre")

          expect(subject).not_to have_css(".fr-badge", text: "suggestion")
          expect(subject).not_to have_button("Appliquer les suggestions et poursuivre")
        end
      end
    end
    context 'when state is failed' do
      let(:state) { 'failed' }

      it 'shows error message and retry button' do
        expect(subject).to have_content("La recherche de suggestions a échoué, veuillez réessayer.")
        expect(subject).to have_button("Relancer la recherche de suggestions")
      end
    end
    context 'when state is accepted' do
      let(:state) { 'accepted' }

      it 'shows accepted message and continue link' do
        expect(subject).to have_text("Vous avez déjà")
        expect(subject).to have_text("accepté")
        expect(subject).to have_link("Poursuivre le parcours d’amélioration")
      end
    end
    context 'when state is skipped' do
      let(:state) { 'skipped' }

      it 'shows skipped message and continue link' do
        expect(subject).to have_text("Vous avez déjà")
        expect(subject).to have_text("ignoré")
        expect(subject).to have_link("Poursuivre le parcours d’amélioration")
      end
    end
  end

  describe '#stepper_finished?' do
    let(:state) { 'accepted' }
    let(:component) { described_class.new(llm_rule_suggestion: llm_rule_suggestion) }
    let(:tunnel_id) { SecureRandom.hex(3) }

    context 'when tunnel is complete' do
      let(:rule) { LLMRuleSuggestion.rules.fetch(LLM::Rule::SEQUENCE.last) }
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule:, schema_hash:, state:) }
      let!(:first_step) do
        create(:llm_rule_suggestion,
          procedure_revision: procedure.draft_revision,
          tunnel_id:,
          rule: LLMRuleSuggestion::RULE_SEQUENCE.first,
          state: 'accepted',
          created_at: 2.days.ago)
      end

      it 'returns true' do
        expect(component.stepper_finished?).to be true
      end
    end

    context 'when tunnel_first_step is missing' do
      let(:rule) { LLMRuleSuggestion.rules.fetch(LLM::Rule::SEQUENCE.last) }

      it 'returns false' do
        expect(component.stepper_finished?).to be false
      end
    end

    context 'when tunnel_last_step_finished is missing' do
      let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }

      it 'returns false' do
        expect(component.stepper_finished?).to be false
      end
    end

    context 'when not on last rule' do
      let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }
      let!(:first_step) do
        create(:llm_rule_suggestion,
          procedure_revision: procedure.draft_revision,
          rule: LLMRuleSuggestion::RULE_SEQUENCE.first,
          state: 'accepted',
          created_at: 2.days.ago)
      end

      it 'returns false' do
        expect(component.stepper_finished?).to be false
      end
    end
  end
end
