# frozen_string_literal: true

describe "Dossier en_construction", js: true do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :for_individual, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_populated_champs, user:, procedure:) }
  let(:mandatory) { false }
  let(:types_de_champ_public) { [{ type: :piece_justificative, stable_id: 99, mandatory: }] }
  let(:champ) { dossier.project_champs_public.find { _1.stable_id == 99 } }

  def user_buffer_champ
    dossier.reload.with_update_stream(user).project_champs_public.find { _1.stable_id == 99 }
  end

  scenario 'delete a non mandatory piece justificative' do
    visit_dossier(dossier)

    expect(page).not_to have_button("Remplacer")
    find("button", text: "Supprimer le fichier toto.txt").click

    live_region_selector = "##{champ.focusable_input_id}-aria-live"
    expect(page).to have_css(live_region_selector, text: "La pièce jointe (toto.txt) a bien été supprimée.", visible: :all)
    expect(page).not_to have_button("Supprimer le fichier toto.txt")
  end

  context "with a mandatory piece justificative" do
    let(:mandatory) { true }

    scenario 'remplace a mandatory piece justificative' do
      visit_dossier(dossier)

      find("button", text: "Supprimer le fichier toto.txt").click
      live_region_selector = "##{champ.focusable_input_id}-aria-live"
      expect(page).to have_css(live_region_selector, text: "La pièce jointe (toto.txt) a bien été supprimée.", visible: :all)

      input_selector = "##{champ.focusable_input_id}"
      expect(page).to have_selector(input_selector)
      find(input_selector).attach_file(Rails.root.join('spec/fixtures/files/file.pdf'))

      wait_until { user_buffer_champ.piece_justificative_file.first&.filename == 'file.pdf' }
      expect(page).to have_text("file.pdf")
    end
  end

  context "with a mandatory titre identite" do
    let(:types_de_champ_public) { [{ type: :titre_identite, stable_id: 99, mandatory: true }] }

    scenario 'remplace a mandatory titre identite' do
      visit_dossier(dossier)

      find("button", text: "Supprimer le fichier toto.png").click
      live_region_selector = "##{champ.focusable_input_id}-aria-live"
      expect(page).to have_css(live_region_selector, text: "La pièce jointe (toto.png) a bien été supprimée.", visible: :all)

      input_selector = "##{champ.focusable_input_id}"
      expect(page).to have_selector(input_selector)
      find(input_selector).attach_file(Rails.root.join('spec/fixtures/files/white.png'))

      wait_until { user_buffer_champ.piece_justificative_file.first&.filename == 'white.png' }
      expect(page).to have_text("white.png")
    end
  end

  context "with a RNA champ" do
    let(:types_de_champ_public) { [{ type: :rna, stable_id: 99, mandatory: true, libelle: "Num RNA" }] }

    scenario "can update a dynamic champ" do
      visit_dossier(dossier)

      fill_in("Num RNA", with: 'W751004076')

      wait_until { user_buffer_champ.value == 'W751004076' }
      expect(page).to have_text("Ce RNA correspond à")
    end
  end

  private

  def visit_dossier(dossier)
    visit modifier_dossier_path(dossier)

    expect(page).to have_current_path(new_user_session_path)
    fill_in 'user_email', with: user.email
    fill_in 'user_password', with: user.password
    click_on 'Se connecter'

    expect(page).to have_current_path(modifier_dossier_path(dossier))
  end
end
