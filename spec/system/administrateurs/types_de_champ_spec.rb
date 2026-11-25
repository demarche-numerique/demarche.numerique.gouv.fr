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
      expect(page).to have_content("Informations complémentaires au champ Numéro SIRET")
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
    select_type_de_champ('Pièce à joindre')

    find('.attachment-field input[type=file]').attach_file(Rails.root + 'spec/fixtures/files/file.pdf')

    # Expect the files to be uploaded immediately
    expect(page).to have_text('file.pdf')

    # Verify attachment is persisted in database
    tdc = procedure.active_revision.public_root_type_de_champs.first
    wait_until { tdc.reload.piece_justificative_template.attached? }
    expect(tdc.piece_justificative_template).to be_attached
    expect(tdc.piece_justificative_template.filename.to_s).to eq('file.pdf')

    # Test deleting the template
    click_on 'Supprimer le fichier file.pdf'
    expect(page).not_to have_button('Supprimer le fichier file.pdf')
    wait_until { !tdc.reload.piece_justificative_template.attached? }
    expect(tdc.piece_justificative_template.attached?).to be(false)
  end

  context "with an explication champ" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :explication }]) }

    scenario "adding a notice explicative" do
      expect(page).to have_text('Notice explicative')

      find('.attachment-field input[type=file]').attach_file(Rails.root + 'spec/fixtures/files/file.pdf')

      expect(page).to have_text('file.pdf')

      tdc = procedure.active_revision.public_root_type_de_champs.first
      wait_until { tdc.reload.notice_explicative.attached? }
      expect(tdc.notice_explicative).to be_attached

      # Test de suppression
      click_on 'Supprimer le fichier file.pdf'

      wait_until { !tdc.reload.notice_explicative.attached? }
      expect(tdc.notice_explicative.attached?).to be(false)
    end
  end

  context "with a communes champ" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :communes }]) }

    # A background underline spans the whole <button> box once its label wraps (#14216).
    scenario "the info button is underlined like a link, line by line" do
      button = find_button('Comment fonctionne ce champ ?')
      style = page.evaluate_script(<<~JS, button)
        ((el) => { const s = getComputedStyle(el); return [s.textDecorationLine, s.backgroundImage] })(arguments[0])
      JS

      expect(style).to eq(['underline', 'none'])
    end
  end

  context "with a drop_down_list champ" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :drop_down_list, libelle: 'Choix de dessert' }]) }

    scenario "importing a CSV referentiel" do
      expect(page).to have_text('Choix de dessert')

      # Click on "Import référentiel" radio button
      find('label', text: 'Import référentiel').click
      expect(page).to have_text('Fichier de référentiel à importer (CSV)')

      # Upload CSV file
      tdc = procedure.active_revision.public_root_type_de_champs.first
      file_input = find("##{dom_id(tdc, :import_referentiel)}", visible: :all)
      file_input.attach_file(Rails.root.join('spec/fixtures/files/modele-import-referentiel.csv'))

      # Wait for referentiel to be created
      wait_until { tdc.reload.referentiel.present? }

      expect(page).to have_text('3 options importées')
      expect(page).to have_text('modele-import-referentiel.csv')

      # Verify referentiel was created correctly
      referentiel = tdc.referentiel
      expect(referentiel).to be_a(Referentiels::CsvReferentiel)
      expect(referentiel.items.count).to eq(3)
      expect(referentiel.headers).to eq(['Dessert', 'Poids (g)', 'Calorie (kcal)'])
    end
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

  # Regression guards for the client-side morph. A save re-renders its champ
  # and every champ below it, a move re-renders the moved champ and its new
  # neighbour: neither must discard what the admin is typing in a re-rendered
  # component. The test debounce is 0, so each scenario first builds two named
  # champs, then reloads the page with a real debounce so the typed value is
  # still unsent when the other request's response lands.
  def two_champs_with_a_slow_autosave
    add_champ
    hide_autonotice_message
    fill_in 'Libellé du champ', with: 'premier champ'
    within(find('.type-de-champ-add-button', match: :first)) { add_champ }
    within '.type-de-champ:nth-child(2)' do
      fill_in 'Libellé du champ', with: 'second champ'
    end
    wait_until { root_libelles == ['premier champ', 'second champ'] }

    allow(Rails.application.config).to receive(:ds_autosave).and_return(debounce_delay: 2_000, status_visible_duration: 500)
    page.refresh
    expect(page).to have_selector('.type-de-champ', count: 2)
  end

  def root_libelles
    procedure.active_revision.reload.public_root_type_de_champs.map(&:libelle)
  end

  def root_tdc(libelle)
    procedure.active_revision.reload.public_root_type_de_champs.find { it.libelle == libelle }
  end

  scenario "saving a champ while the one below holds an unsaved value" do
    two_champs_with_a_slow_autosave

    within '.type-de-champ:nth-child(2)' do
      fill_in 'Description du champ (optionnel)', with: 'description en cours de saisie'
    end
    # a new champ is mandatory by default: unchecking is what triggers a save
    within '.type-de-champ:nth-child(1)' do
      uncheck 'Champ obligatoire'
    end

    wait_until { !root_tdc('premier champ').mandatory? }
    within '.type-de-champ:nth-child(2)' do
      expect(page).to have_field('Description du champ (optionnel)', with: 'description en cours de saisie')
    end
    wait_until { root_tdc('second champ').description == 'description en cours de saisie' }
  end

  scenario "moving a champ while its new neighbour holds an unsaved value" do
    two_champs_with_a_slow_autosave

    within '.type-de-champ:nth-child(1)' do
      fill_in 'Description du champ (optionnel)', with: 'description en cours de saisie'
    end
    within '.type-de-champ:nth-child(2)' do
      click_on 'Déplacer le champ vers le haut'
    end

    wait_until { root_libelles == ['second champ', 'premier champ'] }
    within '.type-de-champ:nth-child(2)' do
      expect(page).to have_field('Libellé du champ', with: 'premier champ')
      expect(page).to have_field('Description du champ (optionnel)', with: 'description en cours de saisie')
    end
    wait_until { root_tdc('premier champ').description == 'description en cours de saisie' }
  end

  scenario "adding a repetition champ" do
    add_champ
    hide_autonotice_message

    select_type_de_champ('Bloc répétable')
    fill_in 'Libellé du champ', with: 'libellé de champ'

    expect(page).to have_content('Formulaire enregistré')
    # The notice alone is not a reliable sync point; poll the DB so the
    # refresh can't race the in-flight saves.
    wait_until do
      tdc = procedure.active_revision.reload.public_root_type_de_champs.first
      tdc&.repetition? && tdc.libelle == 'libellé de champ'
    end
    page.refresh

    within '.type-de-champ .type-de-champ-children' do
      click_on 'Ajouter un champ'

      fill_in 'Libellé du champ', with: 'libellé de champ 1'
    end

    expect(page).to have_content('Formulaire enregistré')
    expect(page).to have_content('Supprimer', count: 2)

    page.all('.fr-icon-add-line')[2].click

    within '.type-de-champ:nth-child(2)' do
      select_type_de_champ('Bloc répétable')
      fill_in 'Libellé du champ', with: 'libellé de champ 2'
    end

    expect(page).to have_content('Supprimer', count: 3)
  end

  scenario "adding a carte champ" do
    add_champ
    hide_autonotice_message

    select_type_de_champ('Carte')
    # Wait for the type-switch re-render to actually land in the DOM (a carte-only
    # field) before filling the shared "Libellé" input. A DB poll only proves the
    # server committed; the morph can still be in flight and rebuild the input we
    # just typed into, dropping the keystroke autosave (an empty libellé is saved).
    expect(page).to have_field('Cadastres')

    fill_in 'Libellé du champ', with: 'Libellé de champ carte', fill_options: { clear: :backspace }
    check 'Cadastres'
    expect(page).to have_content('Formulaire enregistré')

    # Autosaves are serialized and coalesced client-side, so the last save
    # carries the whole form; poll for it before refreshing away.
    wait_until do
      tdc = procedure.active_revision.reload.public_root_type_de_champs.first
      tdc&.libelle == 'Libellé de champ carte' && tdc.layer_enabled?(:cadastres)
    end

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

    select_type_de_champ('Choix simple')

    # 'Options de la liste' only exists once the type-switch re-render has
    # landed, so fill_in also synchronizes on the morph.
    fill_in 'Options de la liste', with: 'Un menu', fill_options: { clear: :backspace }
    check "Proposer une option « autre » avec un texte libre"
    expect(page).to have_content('Formulaire enregistré')

    # Autosaves are serialized and coalesced client-side, so the last save
    # carries the whole form; poll for it before refreshing away.
    wait_until do
      tdc = procedure.active_revision.reload.public_root_type_de_champs.first
      tdc&.drop_down_options == ['Un menu'] && tdc.drop_down_other == "1"
    end

    page.refresh

    expect(page).to have_content('Un menu')
  end

  scenario "adding a number champ accepting decimals" do
    add_champ
    hide_autonotice_message

    select_type_de_champ('Nombre')
    check 'Ce nombre peut comprendre des chiffres après la virgule (décimal)', allow_label_click: true
    expect(page).to have_content('Formulaire enregistré')

    wait_until { procedure.active_revision.reload.public_root_type_de_champs.first&.decimal_number? }

    page.refresh

    expect(page).to have_checked_field('Ce nombre peut comprendre des chiffres après la virgule (décimal)')
  end

  context "estimated duration visible" do
    scenario "displaying the estimated fill duration" do
      # It doesn't display anything when there are no champs
      expect(page).not_to have_content('Durée de remplissage estimée')

      # It displays the estimate when adding a new champ
      add_champ
      select_type_de_champ('Pièce à joindre')
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
      select_type_de_champ('Pièce à joindre')
      expect(page).not_to have_content('Durée de remplissage estimée')
    end
  end

  context 'header sections' do
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { libelle: 'premier' },
        { libelle: 'titre' },
        { libelle: 'second' },
        { libelle: 'dernier' },
      ])
    end

    def layout(type_de_champs = procedure.draft_revision.reload.public_type_de_champs)
      type_de_champs.map { it.header_section? ? { it.libelle => layout(it.children) } : it.libelle }
    end

    def card(libelle) = find('.type-de-champ-container', text: nil) { |card| card.has_field?('Libellé du champ', with: libelle, wait: false) }

    scenario 'a champ becomes a header section, takes what follows, and champs move in and out of it' do
      titre = procedure.draft_revision.type_de_champs.find { it.libelle == 'titre' }
      select_type_de_champ('Titre de section', from: dom_id(titre, :type_champ))
      wait_until { layout == ['premier', { 'titre' => [] }, 'second', 'dernier'] }
      expect(page).to have_text('Titre de niveau 1')
      # the summary of the page follows
      expect(page).to have_link('titre')

      within(card('titre')) { click_on 'Inclure les champs qui suivent' }
      wait_until { layout == ['premier', { 'titre' => ['second', 'dernier'] }] }
      expect(page).to have_css("##{dom_id(titre, :types_de_champ_editor_block)} > li.type-de-champ", count: 2)
      # the button is gone with what it took: the focus stays on the card
      expect(page).to have_css("##{dom_id(titre, :libelle)}:focus")
      expect(page).to have_select(dom_id(titre, :move_to_place), options: ['Déplacer le champ après'])

      within(card('dernier')) { click_on 'Sortir le champ de sa section' }
      wait_until { layout == ['premier', { 'titre' => ['second'] }, 'dernier'] }
      # on the move back in: it has no section to leave any more
      expect(page).to have_css("##{dom_id(procedure.draft_revision.type_de_champs.find { it.libelle == 'dernier' }, :move_in_button)}:focus")

      within(card('dernier')) { click_on 'Faire entrer le champ dans la section qui le précède' }
      wait_until { layout == ['premier', { 'titre' => ['second', 'dernier'] }] }

      # the first of a section moves out of it, right before
      within(card('second')) { click_on 'Déplacer le champ vers le haut' }
      wait_until { layout == ['premier', 'second', { 'titre' => ['dernier'] }] }
      expect(page).to have_css("##{dom_id(titre, :types_de_champ_editor_block)} > li.type-de-champ", count: 1)

      # removing the section leaves what it holds in its place
      within(card('titre')) { accept_alert { click_on 'Supprimer' } }
      wait_until { layout == ['premier', 'second', 'dernier'] }
      expect(page).to have_no_link('titre')
      expect(page).to have_css('.types-de-champ-editor > .types-de-champ-block > li.type-de-champ', count: 3)
    end
  end

  context 'moving to a place' do
    let(:procedure) { create(:procedure, public_type_de_champs: tdcs) }
    let(:draft) { procedure.draft_revision }

    def select_of(type_de_champ) = "##{dom_id(type_de_champ, :move_to_place)}"
    def positions(type_de_champs) = type_de_champs.map { find("##{dom_id(it, :type_de_champ_editor)} > .type-de-champ-container .position").text }

    context 'with root champs' do
      let(:tdcs) do
        [
          { type: :text, libelle: 'first_tdc' },
          { type: :header_section, libelle: 'section', children: [{ type: :text, libelle: 'middle_tdc' }] },
          { type: :text, libelle: 'last_tdc' },
        ]
      end
      let!(:first) { draft.public_root_type_de_champs.first }
      let!(:section) { draft.public_root_type_de_champs.second }
      let!(:last) { draft.public_root_type_de_champs.last }

      scenario 'the select only holds the place of its champ by default' do
        expect(page).to have_selector("#{select_of(first)} option", count: 1)
        expect(page.find(select_of(first)).all("option").first.value).to eq("after:#{first.stable_id}")
      end

      scenario 'when the select is focused, it lists the places of the form' do
        page.find(select_of(first)).click
        expect(page).to have_selector("#{select_of(first)} option", count: 6)
        expect(page.find(select_of(first)).find("option[selected]").value).to eq("after:#{first.stable_id}")
        expect(page.find(select_of(first)).all("option").map(&:text)).to eq(['Au début', '1 - first_tdc', '2 - section', '— 3 - middle_tdc', '(après la section « section »)', '4 - last_tdc'])

        # a header section does not move within itself
        page.find(select_of(section)).click
        expect(page.find(select_of(section)).all("option[disabled]").map(&:text)).to eq(['2 - section', '— 3 - middle_tdc', '(après la section « section »)'])

        # renaming a tdc renames its option
        within "##{dom_id(first, :type_de_champ_editor)}" do
          fill_in 'Libellé du champ', with: 'renamed'
        end
        wait_until { first.reload.libelle == 'renamed' }
        # wait until turbo response
        expect(page).to have_text('Formulaire enregistré')
        page.find(select_of(first)).click
        expect(page.find(select_of(first)).all("option").map(&:text)).to include('1 - renamed')
      end

      scenario 'when the select is changed, it moves the champ' do
        page.find(select_of(first)).click # seeds
        page.find(select_of(first)).select('4 - last_tdc')
        wait_until { draft.reload.public_type_de_champs.map(&:libelle) == ['section', 'last_tdc', 'first_tdc'] }
        # wait until turbo response
        expect(page).to have_text('Formulaire enregistré')

        # the champs which sit elsewhere say so
        expect(positions(draft.public_root_type_de_champs)).to eq(['1', '2', '3', '4'])

        # right after the title of the section: first of what it holds
        page.find(select_of(last)).click
        page.find(select_of(last)).select('1 - section')
        wait_until { draft.reload.type_de_champ(section.stable_id).children.map(&:libelle) == ['last_tdc', 'middle_tdc'] }
        expect(page).to have_css("##{dom_id(section, :types_de_champ_editor_block)} > li.type-de-champ", count: 2)
        expect(positions(draft.public_root_type_de_champs)).to eq(['1', '2', '3', '4'])
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
      let!(:repetition) { draft.public_type_de_champs.second }
      let!(:first_child) { repetition.children.first }

      scenario 'the select of a child of the repetition only holds its place by default' do
        expect(page).to have_selector("#{select_of(first_child)} option", count: 1)
        expect(page.find(select_of(first_child)).all("option").first.value).to eq("after:#{first_child.stable_id}")
      end

      scenario 'when it is focused, it lists the places of the repetition only' do
        page.find(select_of(first_child)).click

        expect(page.find(select_of(first_child)).all("option").map(&:text)).to eq(['Au début', '1 - child_first_tdc', '2 - child_second_tdc'])
      end

      scenario 'when it is changed, the champ moves within the repetition' do
        page.find(select_of(first_child)).click
        page.find(select_of(first_child)).select('2 - child_second_tdc')
        wait_until { draft.reload.type_de_champ(repetition.stable_id).children.map(&:libelle) == ['child_second_tdc', 'child_first_tdc'] }
        # wait until turbo response
        expect(page).to have_text('Formulaire enregistré')

        expect(positions(draft.type_de_champ(repetition.stable_id).children)).to eq(['1', '2'])
        expect(draft.public_type_de_champs.map(&:libelle)).to eq(['root_first_tdc', 'root_second_tdc', 'root_thrid_tdc'])
      end

      scenario 'can configure limit repetitions on repetition champ' do
        repetition_tdc = repetition

        find("label[for='#{dom_id(repetition_tdc, :limit_repetitions)}']").click
        wait_until { repetition_tdc.reload.limit_repetitions == "1" }
        expect(page).to have_content('Formulaire enregistré')

        fill_in dom_id(repetition_tdc, :min_repetitions), with: '2'
        wait_until { repetition_tdc.reload.min_repetitions == "2" }

        fill_in dom_id(repetition_tdc, :max_repetitions), with: '5'
        wait_until { repetition_tdc.reload.max_repetitions == "5" }

        find("label[for='#{dom_id(repetition_tdc, :limit_repetitions)}']").click
        wait_until { repetition_tdc.reload.limit_repetitions == "0" }
        expect(repetition_tdc.reload.min_repetitions).to be_nil
        expect(repetition_tdc.reload.max_repetitions).to be_nil
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
      expect(page).to have_content("Les modifications effectuées ne seront visibles qu’à la prochaine publication")
      expect(page).to have_button('Publier les modifications')

      expect(page).to have_field('Libellé du champ', with: 'Premier champ')

      # Ajouter le deuxième champ
      find('.fr-btn.fr-btn--secondary.fr-btn--icon-left.fr-icon-add-line', match: :first).click

      expect(page).to have_selector('.type-de-champ', count: 2, wait: 5)

      within all('.type-de-champ').last do
        fill_in 'Libellé du champ', with: 'Deuxième champ'
        select_type_de_champ('Choix simple')
        fill_in "Options de la liste", with: "" # make tdc invalid
      end

      expect(page).to have_field('Libellé du champ', with: 'Premier champ')
      expect(page).to have_field('Libellé du champ', with: 'Deuxième champ')

      expect(page).to have_selector('.sticky-header.sticky-header-warning')
      expect(page).to have_content("Les modifications effectuées ne seront visibles qu’à la prochaine publication")
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
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret, libelle: "SIRET de test" }]) }

    scenario "loads modal content only when clicked" do
      visit champs_admin_procedure_path(procedure)

      expect(page).not_to have_content("Informations complémentaires au champ Numéro SIRET")
      within '.type-de-champ' do
        click_button "Liste des informations remontées"
      end

      within "#api-champ-columns-modal" do
        expect(page).to have_content("Informations complémentaires au champ Numéro SIRET")
        expect(page).to have_content("Entreprise raison sociale")
        expect(page).not_to have_content("SIRET de test – Commune") # no champ libelle

        click_button "Fermer"
      end

      expect(page).not_to have_selector("#api-champ-columns-modal[open]")
      within '.type-de-champ' do
        click_button "Liste des informations remontées"
      end
      expect(page).to have_content("Informations complémentaires au champ Numéro SIRET")
    end
  end

  context "Commune and Address field modals" do
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
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
