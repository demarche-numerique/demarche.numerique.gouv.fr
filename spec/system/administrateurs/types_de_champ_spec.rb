# frozen_string_literal: true

describe 'As an administrateur I can edit types de champ', js: true do
  include ActionView::RecordIdentifier

  let(:administrateur) { procedure.administrateurs.first }
  let(:estimated_duration_visible) { true }
  let(:procedure) { create(:procedure, estimated_duration_visible:) }

  before do
    login_as administrateur.user, scope: :user
    visit champs_admin_procedure_path(procedure)
  end

  context "procedure is for individual" do
    let(:procedure) { create(:procedure, for_individual: true) }

    scenario "warn about fields already present in identity steps" do
      expect(page).to have_content("Les informations suivantes concernant le demandeur sont déjà renseignées dans la première étape Identité du formulaire :")
      expect(page).to have_content("Il est donc inutile de les redemander dans d’autres champs du formulaire.")
      expect(page).not_to have_content("Le Numéro SIRET concernant le demandeur est déjà renseigné dans la première étape Identification du formulaire.")
    end
  end

  context "procedure is not for individual" do
    scenario "warn about fields already present in identity steps" do
      expect(page).to have_content("Le Numéro SIRET concernant le demandeur est déjà renseigné dans la première étape Identification du formulaire.")
      expect(page).to have_content("Il est donc inutile de les redemander dans d’autres champs du formulaire.")
      expect(page).not_to have_content("Les informations suivantes concernant le demandeur sont déjà renseignées dans la première étape Identité du formulaire :")

      expect(page).to have_content("Il est donc inutile de les redemander dans d’autres champs du formulaire. ")
      within '.fr-callout' do
        click_button "Liste des informations remontées"
      end
      expect(page).to have_content("Informations complémentaires au champ Numéro Siret")
      expect(page).to have_content("Entreprise raison sociale")
    end
  end

  scenario "adding a new champ" do
    add_champ

    fill_in 'Libellé du champ', with: 'libellé de champ'
    expect(page).to have_content('Formulaire enregistré')
  end

  scenario "adding a piece justificative template" do
    add_champ
    select('Pièce à joindre', from: 'Type de champ')

    find('.attachment input[type=file]').attach_file(Rails.root + 'spec/fixtures/files/file.pdf')

    # Expect the files to be uploaded immediately
    expect(page).to have_text('file.pdf')
  end

  scenario "adding multiple champs" do
    # Champs are created when clicking the 'Add field' button
    add_champ
    within(find('.type-de-champ-add-button', match: :first)) {
      add_champ
    }
    within(find('.type-de-champ-add-button', match: :first)) {
      add_champ
    }

    # Champs are automatically saved
    expect(page).to have_button('Ajouter un champ', disabled: false)
    page.refresh
    expect(page).to have_selector('.type-de-champ', count: 3)

    # Multiple champs can be edited
    within '.type-de-champ:nth-child(1)' do
      fill_in 'Libellé du champ', with: 'libellé de champ 0'
    end
    within '.type-de-champ:nth-child(2)' do
      fill_in 'Libellé du champ', with: 'libellé de champ 1'
    end
    expect(page).to have_content('Formulaire enregistré')

    # Champs can be deleted
    within '.type-de-champ:nth-child(3)' do
      accept_alert do
        click_on 'Supprimer'
      end
    end
    expect(page).to have_content('Supprimer', count: 2)

    within '.type-de-champ:nth-child(2)' do
      fill_in 'Libellé du champ', with: 'edited libellé de champ 1'
    end
    expect(page).to have_content('Formulaire enregistré')
    expect(page).to have_content('Supprimer', count: 2)

    page.refresh
    expect(page).to have_content('Supprimer', count: 2)
  end

  scenario "removing champs" do
    add_champ
    hide_autonotice_message

    fill_in 'Libellé du champ', with: 'libellé de champ'
    expect(page).to have_content('Formulaire enregistré')

    page.refresh

    accept_alert do
      click_on 'Supprimer'
    end
    expect(page).to have_content('Formulaire enregistré')
    expect(page).to have_content('Supprimer', count: 0)
    page.refresh

    expect(page).to have_content('Supprimer', count: 0)
  end

  scenario "adding an invalid champ" do
    add_champ
    hide_autonotice_message

    fill_in 'Libellé du champ', with: ''
    fill_in 'Description du champ (optionnel)', with: 'description du champ'
    expect(page).to have_no_text(:visible, 'Formulaire enregistré')

    fill_in 'Libellé du champ', with: 'libellé de champ'
    expect(page).to have_text('Formulaire enregistré')
  end

  scenario "adding a repetition champ" do
    add_champ
    hide_autonotice_message

    select('Bloc répétable', from: 'Type de champ')
    fill_in 'Libellé du champ', with: 'libellé de champ'

    expect(page).to have_content('Formulaire enregistré')
    page.refresh

    within '.type-de-champ .editor-block' do
      click_on 'Ajouter un champ'

      fill_in 'Libellé du champ', with: 'libellé de champ 1'
    end

    expect(page).to have_content('Formulaire enregistré')
    expect(page).to have_content('Supprimer', count: 2)

    page.all('.fr-icon-add-line')[2].click

    within '.type-de-champ:nth-child(2)' do
      select('Bloc répétable', from: 'Type de champ')
      fill_in 'Libellé du champ', with: 'libellé de champ 2'
    end

    expect(page).to have_content('Supprimer', count: 3)
  end

  scenario "adding a carte champ" do
    add_champ
    hide_autonotice_message

    select('Carte', from: 'Type de champ')
    fill_in 'Libellé du champ', with: 'Libellé de champ carte', fill_options: { clear: :backspace }
    check 'Cadastres'

    wait_until { procedure.active_revision.types_de_champ_public.first.layer_enabled?(:cadastres) }
    wait_until { procedure.active_revision.types_de_champ_public.first.libelle == 'Libellé de champ carte' }
    expect(page).to have_content('Formulaire enregistré')

    page.refresh
    preview_window = window_opened_by { click_on 'Prévisualiser le formulaire' }
    within_window(preview_window) do
      expect(page).to have_content('Libellé de champ carte')
      expect(page).to have_content('Ajouter un point sur la carte')
      fill_in 'Ajouter un point sur la carte', with: "48°52'27\"N 002°54'32\"E"
      click_on 'Ajouter le point avec les coordonnées saisies sur la carte'
    end
  end

  scenario "adding a dropdown champ" do
    add_champ
    hide_autonotice_message

    select('Choix simple', from: 'Type de champ')
    fill_in 'Libellé du champ', with: 'Libellé de champ menu déroulant', fill_options: { clear: :backspace }
    fill_in 'Options de la liste', with: 'Un menu', fill_options: { clear: :backspace }
    check "Proposer une option « autre » avec un texte libre"

    wait_until { procedure.active_revision.reload.types_de_champ_public.first.drop_down_options == ['Un menu'] }
    wait_until { procedure.active_revision.reload.types_de_champ_public.first.drop_down_other == "1" }
    expect(page).to have_content('Formulaire enregistré')

    page.refresh

    expect(page).to have_content('Un menu')
  end

  context "estimated duration visible" do
    scenario "displaying the estimated fill duration" do
      # It doesn't display anything when there are no champs
      expect(page).not_to have_content('Durée de remplissage estimée')

      # It displays the estimate when adding a new champ
      add_champ
      select('Pièce à joindre', from: 'Type de champ')
      expect(page).to have_content('Durée de remplissage estimée : 3 min')

      # It updates the estimate when updating the champ
      uncheck 'Champ obligatoire'
      expect(page).to have_content('Durée de remplissage estimée : 2 min')

      # It updates the estimate when removing the champ
      accept_alert do
        click_on 'Supprimer'
      end
      expect(page).not_to have_content('Durée de remplissage estimée')
    end
  end

  context "estimated duration not visible" do
    let(:estimated_duration_visible) { false }

    scenario "hide the estimated fill duration" do
      # It doesn't display anything when there are no champs
      expect(page).not_to have_content('Durée de remplissage estimée')

      # It displays the estimate when adding a new champ
      add_champ
      select('Pièce à joindre', from: 'Type de champ')
      expect(page).not_to have_content('Durée de remplissage estimée')
    end
  end

  context 'header section' do
    scenario 'with public tdc, having invalid order, it pops up errors summary' do
      add_champ
      select('Titre de section', from: 'Type de champ')
      wait_until { procedure.reload.active_revision.types_de_champ_public.first&.type_champ == TypeDeChamp.type_champs.fetch(:header_section) }
      first_header = procedure.active_revision.types_de_champ_public.first
      select('Titre de niveau 1', from: dom_id(first_header, :header_section_level))

      within(find('.type-de-champ-add-button', match: :first)) {
        add_champ
      }

      wait_until { procedure.reload.active_revision.types_de_champ_public.count == 2 }
      second_header = procedure.active_revision.types_de_champ_public.last
      select('Titre de section', from: dom_id(second_header, :type_champ))
      wait_until { procedure.reload.active_revision.types_de_champ_public.last&.type_champ == TypeDeChamp.type_champs.fetch(:header_section) }
      select('Titre de niveau 2', from: dom_id(second_header, :header_section_level))

      within(".types-de-champ-block li:first-child") do
        accept_alert do
          click_on 'Supprimer'
        end
      end
      expect(page).to have_content("devrait être précédé d’un titre de niveau 1")

      # check summary refresh
      procedure.reload.active_revision.types_de_champ_private.each do |header_section|
        expect(page).to have_link(header_section.libelle)
      end
    end
  end

  context 'move and morph' do
    let(:procedure) { create(:procedure, types_de_champ_public: tdcs) }
    let!(:initial_first_coordinate) { procedure.draft_revision.revision_types_de_champ_public[0] }
    let!(:initial_second_coordinate) { procedure.draft_revision.revision_types_de_champ_public[1] }
    let!(:initial_third_coordinate) { procedure.draft_revision.revision_types_de_champ_public[2] }

    context 'with root champs' do
      let(:tdcs) do
        [
          { type: :text, libelle: 'first_tdc' },
          { type: :text, libelle: 'middle_tdc' },
          { type: :text, libelle: 'last_tdc' },
        ]
      end
      let(:initial_first_coordinate_selector) { "##{ActionView::RecordIdentifier.dom_id(initial_first_coordinate, :move_and_morph)}" }

      scenario 'root select is empty by default' do
        # at first, select only contains the current coordinate
        expect(page).to have_selector("#{initial_first_coordinate_selector} option", count: 1)
        expect(page.find(initial_first_coordinate_selector).all("option").first.value.to_s).to eq(initial_first_coordinate.stable_id.to_s)
      end

      scenario 'when select is focused, it seeds its options' do
        # once clicked, the select is updated with root champs options only, preselected on coordinates and have nice libelles
        page.find(initial_first_coordinate_selector).click
        expect(page).to have_selector("#{initial_first_coordinate_selector} option", count: 3)
        expect(page.find(initial_first_coordinate_selector).find("option[selected]").value.to_s).to eq(initial_first_coordinate.stable_id.to_s)
        expect(page.find(initial_first_coordinate_selector).all("option").map(&:text)).to match_array(['1 - first_tdc', '2 - middle_tdc', '3 - last_tdc'])

        # renaming a tdc renames it's option
        within "##{dom_id(initial_first_coordinate, :type_de_champ_editor)}" do
          fill_in 'Libellé du champ', with: 'renamed'
        end
        wait_until { initial_first_coordinate.reload.libelle == 'renamed' }
        # wait until turbo response
        expect(page).to have_text('Formulaire enregistré')
        page.find(initial_first_coordinate_selector).click
        expect(page).to have_css("#{initial_first_coordinate_selector} option", count: 3)
        expect(page.find(initial_first_coordinate_selector).all("option").map(&:text)).to match_array(['1 - renamed', '2 - middle_tdc', '3 - last_tdc'])
      end

      scenario 'when select is changed, it move the coordinates' do
        page.find(initial_first_coordinate_selector).click # seeds
        page.find(initial_first_coordinate_selector).select(initial_third_coordinate.libelle)
        wait_until do
          procedure.reload.draft_revision.revision_types_de_champ.last.type_de_champ.libelle == initial_first_coordinate.type_de_champ.libelle
        end
        # wait until turbo response
        expect(page).to have_text('Formulaire enregistré')

        # check reorder worked on backend
        reordered_coordinates = [initial_second_coordinate, initial_third_coordinate, initial_first_coordinate]
        expect(procedure.reload.draft_revision.revision_types_de_champ.map(&:stable_id)).to eq(reordered_coordinates.map(&:stable_id))

        # check reorder rerendered champ component between target->destination
        reordered_coordinates.map(&:reload).map do |coordinate|
          expect(page).to have_selector("##{ActionView::RecordIdentifier.dom_id(coordinate, :type_de_champ_editor)} .position", text: coordinate.position + 1)
        end
      end
    end

    context 'with repetition champs' do
      let(:tdcs) do
        [
          { type: :text, libelle: 'root_first_tdc' },
          {
            type: :repetition,
            libelle: 'root_second_tdc',
            children: [
              { type: :text, libelle: 'child_first_tdc' },
              { type: :text, libelle: 'child_second_tdc' },
            ],
          },
          { type: :text, libelle: 'root_thrid_tdc' },
        ]
      end
      let(:children_coordinates) { procedure.draft_revision.revision_types_de_champ.filter { _1.parent.present? } }
      let(:first_child_coordinate_selector) { "##{ActionView::RecordIdentifier.dom_id(children_coordinates.first, :move_and_morph)}" }

      scenario 'first child of repetition select is empty by default' do
        expect(page).to have_selector("#{first_child_coordinate_selector} option", count: 1)
        expect(page.find(first_child_coordinate_selector).all("option").first.value.to_s).to eq(children_coordinates.first.stable_id.to_s)
      end

      scenario 'when first child select is focused, seed with repetition only tdcs' do
        page.find(first_child_coordinate_selector).click
        expect(page).to have_selector("#{first_child_coordinate_selector} option", count: 2)

        opts = page.find(first_child_coordinate_selector).all("option").map(&:text)
        expect(opts).to match_array(children_coordinates.map { "#{_1.position + 1} - #{_1.libelle}" })
      end

      scenario 'when first child select is changed, move champ in repetition' do
        page.find(first_child_coordinate_selector).click
        expect(children_coordinates.first.position).to eq(0)
        page.find(first_child_coordinate_selector).select(children_coordinates.last.libelle)
        # check reorder works on backend
        wait_until do
          children_coordinates.first.reload.position == 1
        end
        # wait until turbo response
        expect(page).to have_text('Formulaire enregistré')

        # check reorder worked on backend
        reordered_coordinates = children_coordinates.reverse
        expect(procedure.reload.draft_revision.revision_types_de_champ.filter { _1.parent.present? }.sort_by(&:position).map(&:stable_id)).to eq(reordered_coordinates.map(&:stable_id))

        # check reorder rerendered champ component between target->destination
        reordered_coordinates.map(&:reload).map do |coordinate|
          expect(page).to have_selector("##{ActionView::RecordIdentifier.dom_id(coordinate, :type_de_champ_editor)} .position", text: coordinate.position + 1)
        end
      end
    end
  end

  context "unpublished changes navbar" do
    let(:procedure) { create(:procedure, :published) }

    before do
      login_as administrateur.user, scope: :user
      visit champs_admin_procedure_path(procedure)
    end

    scenario "navbar behavior for published and unpublished procedures" do
      expect(page).not_to have_selector('.sticky-header.sticky-header-warning')

      # Ajouter le premier champ
      find('.fr-btn.fr-btn--secondary.fr-btn--icon-left.fr-icon-add-line', match: :first).click
      fill_in 'Libellé du champ', with: 'Premier champ'
      expect(page).to have_selector('.sticky-header.sticky-header-warning')
      expect(page).to have_content("Les modifications effectuées ne seront visibles qu'à la prochaine publication")
      expect(page).to have_link('Publier les modifications')

      expect(page).to have_field('Libellé du champ', with: 'Premier champ')

      # Ajouter le deuxième champ
      find('.fr-btn.fr-btn--secondary.fr-btn--icon-left.fr-icon-add-line', match: :first).click

      expect(page).to have_selector('.type-de-champ', count: 2, wait: 5)

      within all('.type-de-champ').last do
        fill_in 'Libellé du champ', with: 'Deuxième champ'
        select 'Choix simple', from: 'Type de champ'
        fill_in "Options de la liste", with: "" # make tdc invalid
      end

      expect(page).to have_field('Libellé du champ', with: 'Premier champ')
      expect(page).to have_field('Libellé du champ', with: 'Deuxième champ')

      expect(page).to have_selector('.sticky-header.sticky-header-warning')
      expect(page).to have_content("Les modifications effectuées ne seront visibles qu'à la prochaine publication")
      expect(page).to have_button('Publier les modifications', disabled: true)

      # Supprime dernier champ
      accept_alert do
        all('.fr-btn--tertiary-no-outline[title="Supprimer le champ"]').last.click
      end

      expect(page).to have_selector('.type-de-champ', count: 1, wait: 5)

      accept_alert do
        click_on "Publier les modifications"
      end

      expect(page).to have_content("démarche publiée")

      unpublished_procedure = create(:procedure)
      visit champs_admin_procedure_path(unpublished_procedure)

      find('.fr-btn.fr-btn--secondary.fr-btn--icon-left.fr-icon-add-line', match: :first).click
      fill_in 'Libellé du champ', with: 'Nouveau champ'
      expect(page).not_to have_selector('.sticky-header.sticky-header-warning')
    end
  end

  context "SIRET field modal" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret, libelle: "SIRET de test" }]) }

    scenario "loads modal content only when clicked" do
      visit champs_admin_procedure_path(procedure)

      expect(page).not_to have_content("Informations complémentaires au champ Numéro Siret")
      within '.type-de-champ' do
        click_button "Liste des informations remontées"
      end

      within "#api-champ-columns-modal" do
        expect(page).to have_content("Informations complémentaires au champ Numéro Siret")
        expect(page).to have_content("Entreprise raison sociale")
        expect(page).not_to have_content("SIRET de test – Commune") # no champ libelle

        click_button "Fermer"
      end

      expect(page).not_to have_selector("#api-champ-columns-modal[open]")
      within '.type-de-champ' do
        click_button "Liste des informations remontées"
      end
      expect(page).to have_content("Informations complémentaires au champ Numéro Siret")
    end
  end

  context "Commune and Address field modals" do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :communes, libelle: "Commune de résidence" },
        { type: :address, libelle: "Adresse du domicile" },
      ])
    end

    scenario "loads modal content only when clicked" do
      visit champs_admin_procedure_path(procedure)

      # Test Commune field
      type_de_champ_elements = all('.type-de-champ')
      within type_de_champ_elements.first do
        expect(page).not_to have_content("Informations complémentaires au champ Commune")
        click_button "Liste des informations remontées"
      end

      within "#api-champ-columns-modal" do
        expect(page).to have_content("Informations complémentaires au champ Commune")
        expect(page).to have_content("Commune")
        expect(page).to have_content("Code INSEE")
        expect(page).to have_content("Département")

        click_button "Fermer"
      end

      expect(page).not_to have_selector("#api-champ-columns-modal[open]")

      # Test Address field
      within type_de_champ_elements.last do
        expect(page).not_to have_content("Informations complémentaires au champ Adresse")
        click_button "Liste des informations remontées"
      end

      within "#api-champ-columns-modal" do
        expect(page).to have_content("Informations complémentaires au champ Adresse")
        expect(page).to have_content("Adresse")
        expect(page).to have_content("Code INSEE")
        expect(page).to have_content("Département")

        click_button "Fermer"
      end

      expect(page).not_to have_selector("#api-champ-columns-modal[open]")
    end
  end
end
