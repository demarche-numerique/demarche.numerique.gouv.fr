# frozen_string_literal: true

describe 'As an administrateur I can use Simpliscore to improve my procedure', js: true do
  let(:administrateur) { procedure.administrateurs.first }
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'NOM' }]) }
  let(:rule) { 'improve_label' }

  before do
    Flipper.enable(:llm_nightly_improve_procedure, procedure)
    login_as administrateur.user, scope: :user
  end

  describe 'complete workflow through all 4 steps' do
    scenario 'navigating through all steps with auto-enchainement' do
      # Step 1: improve_label - use new_simplify entry point
      visit new_simplify_admin_procedure_types_de_champ_path(procedure)

      # Extract tunnel_id from URL
      expect(page).to have_current_path(/simplify\/([a-f0-9]{6})\/improve_label/)
      tunnel_id = current_path.match(/simplify\/([a-f0-9]{6})\//)[1]

      expect(page).to have_content("Libellés et descriptions des champs")
      expect(page).to have_button("Lancer la recherche de suggestions")

      # Launch the search
      click_button "Lancer la recherche de suggestions"
      expect(page).to have_content("Recherche en cours")

      # Simulate completion by updating existing suggestion (created by new_simplify)
      llm_rule_suggestion = procedure.draft_revision.llm_rule_suggestions.find_by!(tunnel_id:, rule: 'improve_label')
      llm_rule_suggestion.update!(state: 'completed')

      create(:llm_rule_suggestion_item,
        llm_rule_suggestion: llm_rule_suggestion,
        stable_id: procedure.draft_revision.revision_types_de_champ_public.first.stable_id,
        payload: { 'stable_id' => procedure.draft_revision.revision_types_de_champ_public.first.stable_id, 'libelle' => 'Nom' })

      visit simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'improve_label')

      expect(page).to have_content(/1\s+suggestion/)
      expect(page).to have_css("input[type='submit'][disabled]")
      expect(page).to have_button("Ignorer cette étape et poursuivre")

      # Verify stepper is shown and has correct text
      expect(page).to have_css('.fr-stepper')
      expect(page).to have_content("Étape suivante")

      # Accept the suggestion by checking the checkbox
      first('input[type="checkbox"][name*="verify_status"]').check(allow_label_click: true)

      expect(page).not_to have_css("input[type='submit'][disabled]")

      click_button "Appliquer les suggestions et poursuivre"

      # Auto-enchainement: Step 2 was created and search launched automatically
      expect(page).to have_current_path(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'improve_structure'))
      expect(page).to have_content("Structure du formulaire")

      # Verify that step 2 suggestion exists (created by auto-enchainement)
      expect(procedure.draft_revision.llm_rule_suggestions.find_by(tunnel_id:, rule: 'improve_structure')).to be_present

      # Step 2: simulate completion
      llm_rule_suggestion_2 = procedure.draft_revision.llm_rule_suggestions.find_by!(tunnel_id:, rule: "improve_structure")
      llm_rule_suggestion_2.update!(state: "completed")

      post_step1_hash = Digest::SHA256.hexdigest(procedure.draft_revision.reload.schema_to_llm.to_json)

      # Schema change detection: verify applying step 1 changed the schema
      expect(post_step1_hash).not_to eq(llm_rule_suggestion.schema_hash)
      # Visit step 1 to verify old suggestion invalidated by schema change
      visit simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: "improve_label")
      expect(page).to have_button("Lancer la recherche de suggestions")
      expect(page).not_to have_css(".fr-badge", text: /\d+ suggestions?/)

      # Pre-create steps 3 and 4
      create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision,
        tunnel_id:, rule: "improve_types", state: "completed", schema_hash: post_step1_hash)
      cleaner_suggestion = create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision,
        tunnel_id:, rule: "cleaner", state: "completed", schema_hash: post_step1_hash)
      create(:llm_rule_suggestion_item,
        llm_rule_suggestion: cleaner_suggestion,
        stable_id: procedure.draft_revision.revision_types_de_champ_public.first.stable_id,
        payload: { "stable_id" => procedure.draft_revision.revision_types_de_champ_public.first.stable_id, "action" => "delete" })

      # Stub job to prevent overwriting pre-created completed suggestions
      allow(LLM::ImproveProcedureJob).to receive(:perform_now)

      # Return to step 2 (already completed)
      visit simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: "improve_structure")
      expect(page).to have_button("Poursuivre")
      click_button "Poursuivre"

      # Step 3: already completed via pre-creation
      expect(page).to have_current_path(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: "improve_types"))
      expect(page).to have_content("Bonne utilisation des types de champs")
      expect(page).to have_button("Poursuivre")
      click_button "Poursuivre"

      # Step 4 (last step): has suggestions — verify "terminer" wording
      expect(page).to have_current_path(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: "cleaner"))
      expect(page).to have_css(".fr-stepper")
      expect(page).to have_button("Ignorer cette étape et terminer")
      expect(page).to have_css("input[type='submit'][value='Appliquer les suggestions et terminer']")

      # Click skip to finish the tunnel (without checking checkbox to avoid schema change)
      click_button "Ignorer cette étape et terminer"

      # After finishing the last step, we stay on cleaner to show the end-of-tunnel message
      expect(page).to have_current_path(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'cleaner'))

      # Should see the end-of-tunnel message
      expect(page).to have_content("Ce parcours d’amélioration de la qualité du formulaire est terminé.")
    end
  end
  describe 'error handling' do
    scenario 'shows error message and retry button when search fails' do
      tunnel_id = SecureRandom.hex(3)
      create(:llm_rule_suggestion,
        procedure_revision: procedure.draft_revision,
        tunnel_id:,
        rule: 'improve_label',
        state: 'failed',
        schema_hash: Digest::SHA256.hexdigest(procedure.draft_revision.schema_to_llm.to_json))

      visit simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'improve_label')

      expect(page).to have_content("La recherche de suggestions a échoué, veuillez réessayer.")
      expect(page).to have_button("Relancer la recherche de suggestions")
    end
  end
end
