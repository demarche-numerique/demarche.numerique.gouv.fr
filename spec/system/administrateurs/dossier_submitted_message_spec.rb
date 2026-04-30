# frozen_string_literal: true

describe 'As an administateur i can setup a DossierSubmittedMessage', js: true do
  let(:procedure) { create(:procedure, :for_individual, administrateurs: [administrateur], instructeurs: [create(:instructeur)]) }
  let(:administrateur) { create(:administrateur, user: create(:user)) }
  before { login_as administrateur.user, scope: :user }

  scenario 'Dossier submitted message' do
    visit edit_admin_procedure_dossier_submitted_message_path(procedure)

    editor = find('.tiptap-editor')
    editor.click

    # La sélection via shift+left peut rater des caractères, on retente si besoin
    bold_ok = false
    3.times do
      editor.send_keys('Texte super important')
      editor.send_keys(*Array.new(15, [:shift, :left])) # Select "super important"
      click_on 'Gras'

      within('#tiptap-preview .tiptap-content') do
        bold_ok = page.has_css?("strong", text: "super important", wait: 1)
      end
      break if bold_ok

      # Raté : on efface tout et on recommence
      editor.send_keys([:control, 'a'])
      editor.send_keys(:backspace)
    end

    within('#tiptap-preview .tiptap-content') do
      expect(page).to have_css("strong", text: "super important")
    end

    # Link modal
    click_on "Ajouter un lien sur le texte sélectionné"
    expect(page).to have_content("Intitulé du lien : super important")
    fill_in "Adresse du lien", with: "Pas un lien"
    click_on "Créer le lien"
    expect(page).to have_content("doit commencer par https")

    fill_in "Adresse du lien", with: "https://example.gouv.fr"
    click_on "Créer le lien"

    within('#tiptap-preview .tiptap-content') do
      expect(page).to have_link('super important', href: "https://example.gouv.fr")
    end

    click_on 'Enregistrer'
    expect(page).to have_content("Les informations de fin de dépot ont bien été sauvegardées.")
    expect(procedure.dossier_submitted_messages.last.json_body["content"].to_s).to include("super important")
  end
end
