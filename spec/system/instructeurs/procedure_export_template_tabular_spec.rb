# frozen_string_literal: true

describe "procedure exports" do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, public_type_de_champs:, instructeurs: [instructeur]) }
  let(:public_type_de_champs) { [{ type: :text }] }

  before do
    login_as(instructeur.user, scope: :user)
  end

  scenario "create an export_template tabular", js: true do
    visit instructeur_procedure_path(procedure)

    find("button", text: "Téléchargements").click

    click_on "Modèles d’export"

    click_on "Créer un modèle d’export tabulaire"

    fill_in "Nom du modèle", with: "Mon modèle"

    find("#informations-usager-fieldset label", text: "Tout sélectionner").click

    within '#informations-usager-fieldset' do
      expect(all('input[type=checkbox]').all?(&:checked?)).to be_truthy
    end

    find("#informations-dossier-fieldset label", text: "Tout sélectionner").click

    within '#informations-dossier-fieldset' do
      expect(all('input[type=checkbox]').all?(&:checked?)).to be_truthy
    end

    click_on "Enregistrer"

    expect(page).to have_content('Mon modèle')

    # check if all usager colonnes are selected
    #
    click_on 'Mon modèle'

    within '#informations-usager-fieldset' do
      expect(all('input[type=checkbox]').all?(&:checked?)).to be_truthy
    end

    within '#informations-dossier-fieldset' do
      expect(all('input[type=checkbox]').all?(&:checked?)).to be_truthy
    end

    # uncheck checkboxes
    find("#informations-dossier-fieldset label", text: "Tout sélectionner").click
    within '#informations-dossier-fieldset' do
      expect(all('input[type=checkbox]').none?(&:checked?)).to be_truthy
    end
  end

  context 'with a repeatable block' do
    let(:public_type_de_champs) { [{ type: :repetition, libelle: 'Enfants', children: [{ type: :text, libelle: 'Prénom' }] }] }
    let(:notice) { '[data-export-template-kind-target="csvOnly"]' }

    scenario 'show the repeatable block notice only for the csv kind', js: true do
      visit new_instructeur_procedure_export_template_path(procedure)

      expect(page).to have_no_css(notice, visible: true)

      choose 'csv', allow_label_click: true
      expect(page).to have_css(notice, visible: true, text: 'Si vous sélectionnez des champs issus d’un bloc répétable')

      choose 'xlsx', allow_label_click: true
      expect(page).to have_no_css(notice, visible: true)
    end

    scenario 'choose to show the repeatable blocks in the Dossiers sheet', js: true do
      visit new_instructeur_procedure_export_template_path(procedure)

      fill_in 'Nom du modèle', with: 'Avec blocs'
      expect(page).to have_checked_field('repetition_layout_sheet')

      choose 'csv', allow_label_click: true
      expect(page).to have_no_field('repetition_layout_inline', visible: true)

      choose 'xlsx', allow_label_click: true
      choose 'repetition_layout_inline', allow_label_click: true
      click_on 'Enregistrer'

      click_on 'Avec blocs'
      expect(page).to have_checked_field('repetition_layout_inline')
    end
  end

  scenario 'no repetition layout without repeatable block', js: true do
    visit new_instructeur_procedure_export_template_path(procedure)

    expect(page).not_to have_field('repetition_layout_sheet')
  end
end
