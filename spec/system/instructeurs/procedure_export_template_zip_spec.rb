# frozen_string_literal: true

describe "procedure exports zip", js: true do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, public_type_de_champs:, instructeurs: [instructeur]) }
  let(:public_type_de_champs) { [{ type: :text }] }

  before do
    login_as(instructeur.user, scope: :user)
  end

  scenario "create an export_template zip" do
    visit instructeur_procedure_path(procedure)

    find("button", text: "Téléchargements").click

    click_on "Modèles d’export"

    click_on "Créer un modèle d’export zip"

    fill_in "Nom du modèle", with: "Mon modèle"

    all('.fr-input-group .fr-tag').find { _1.text == 'SIREN' }.click

    expect(page).to have_content("Sélectionnez les fichiers que vous souhaitez exporter")
    custom_check("export_template_commentaires_attachments")
    custom_check("export_template_avis_attachments")
    custom_check("export_template_justificatif_motivation")
    click_on "Enregistrer"

    expect(page).to have_content("Modèles d’export")
    expect(page).to have_content('a bien été créé')
    expect(page).not_to have_content("Vous n’avez pas le droit de créer un modèle d’export pour ce groupe")

    export_template = ExportTemplate.last
    dossier_folder_template = export_template.dossier_folder.template
    tiptap_tags = dossier_folder_template.dig(:content, 0, :content).filter { _1[:type] == "mention" }
    expect(tiptap_tags.map { _1[:attrs][:label] }).to include("SIREN")
  end

  scenario "the preview follows the chosen dossier" do
    accepte = create(:dossier, :accepte, procedure:)
    en_construction = create(:dossier, :en_construction, procedure:)
    # NFKC turns the state labels' non-breaking spaces into the plain ones the search input gets
    label = -> (dossier) { "N° #{dossier.id} – #{Dossier.human_attribute_name("state.#{dossier.state}").upcase}".unicode_normalize(:nfkc) }

    visit new_instructeur_procedure_export_template_path(procedure, kind: :zip)

    expect(page).to have_button(label.(accepte))
    expect(page).to have_css('#preview', text: "dossier-#{accepte.id}/")

    select_react_option(label.(en_construction), from: "Dossier utilisé pour l’aperçu")

    expect(page).to have_css('#preview', text: "dossier-#{en_construction.id}/")
  end
end
