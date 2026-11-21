# frozen_string_literal: true

# The editor only sends back what an edit changes below the edited champ: after
# each edit, the page must show what a reload would.
describe 'Editing a champ keeps the champs below it up to date', js: true do
  include Logic
  include ActionView::RecordIdentifier

  let_it_be(:procedure, refind: true) do
    create(:procedure, public_type_de_champs: [
      { type: :header_section, libelle: 'Demandeur', level: 1 },
      { type: :drop_down_list, libelle: 'Vous êtes', options: ['Particulier', 'Entreprise'] },
      { type: :yes_no, libelle: 'Majeur' },
      { type: :integer_number, libelle: 'Effectif' },
      { type: :header_section, libelle: 'Entreprise', level: 2 },
      { type: :yes_no, libelle: 'Société cotée' },
      { type: :text, libelle: 'Raison sociale' },
      { type: :header_section, libelle: 'Associés', level: 2 },
      { type: :repetition, libelle: 'Liste des associés', children: [{ type: :text, libelle: 'Nom' }, { type: :text, libelle: 'Part' }] },
    ])
  end

  def tdc(libelle) = procedure.reload.draft_revision.type_de_champs.find { it.libelle == libelle }
  def editor_of(libelle) = "##{dom_id(tdc(libelle), :type_de_champ_editor)}"
  def footer_of(libelle) = "#{editor_of(libelle)} > .type-de-champ-container > .footer"

  def column_of(source) = champ_column_value(source.columns(procedure_id: procedure.id).first)
  def condition_on(source, value) = ds_eq(column_of(source), constant(value))

  # What the editor shows of each champ that the edit of another one can change
  def editor_state
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('li.type-de-champ')).map((li) => {
        const own = (selector) => Array.from(li.querySelectorAll(`:scope > .type-de-champ-container > ${selector}`));
        const option = (o) => [o.textContent.trim(), o.selected, o.disabled];
        const shown = (e) => getComputedStyle(e).display != 'none';
        const condition = '[id^="condition_"]';
        return {
          id: li.id,
          moves: own('.footer :is(.move-up, .move-down)').map(shown),
          position: own('.footer .position').map((e) => e.textContent.trim()),
          levels: own('.head select[name$="[header_section_level]"] option').map(option),
          condition: own(condition).length,
          targets: own(`${condition} td.target option`).map(option),
          values: own(`${condition} td.value option`).map(option),
          errors: own(`${condition} .errors-summary li`).map((e) => e.textContent.trim()),
        };
      })
    JS
  end

  def expect_the_state_of_a_reload
    state = editor_state
    page.refresh
    expect(page).to have_css('body.dom-ready')
    expect(editor_state).to eq(state)
  end

  # Raison sociale reads Vous êtes and Effectif through the display condition
  # of Société cotée
  before_all do
    tdc('Société cotée').update!(condition: ds_and([condition_on(tdc('Vous êtes'), 'Entreprise'), less_than(column_of(tdc('Effectif')), constant(0))]))
    tdc('Raison sociale').update!(condition: condition_on(tdc('Société cotée'), true))
    tdc('Nom').update!(condition: condition_on(tdc('Majeur'), true))
  end

  before do
    login_as procedure.administrateurs.first.user, scope: :user
    visit champs_admin_procedure_path(procedure)
    expect(page).to have_css('body.dom-ready')
  end

  scenario 'adding and removing champs' do
    expect(page).to have_css("#{footer_of('Demandeur')} .move-up", visible: :hidden)
    expect(page).to have_css("#{footer_of('Liste des associés')} .move-down", visible: :hidden)
    # the last repetition hides its own move down button, not the ones of its children
    expect(page).to have_css("#{footer_of('Nom')} .move-down", visible: :visible)

    within("#{editor_of('Liste des associés')} > .type-de-champ-add-button") { add_champ }
    expect(page).to have_css("#{footer_of('Liste des associés')} .move-down", visible: :visible)
    expect_the_state_of_a_reload

    within("#{editor_of('Vous êtes')} > .type-de-champ-add-button") { add_champ }
    within(footer_of('Majeur')) { expect(page).to have_css('.position', exact_text: '4') }
    expect_the_state_of_a_reload

    within(editor_of('Demandeur')) { accept_alert { click_on 'Supprimer' } }
    within(footer_of('Vous êtes')) { expect(page).to have_css('.position', exact_text: '1') }
    expect_the_state_of_a_reload

    within(editor_of('Vous êtes')) { accept_alert { click_on 'Supprimer' } }
    within(editor_of('Société cotée')) { expect(page).to have_css('.errors-summary') }
    expect_the_state_of_a_reload
  end

  scenario 'editing sources cited below' do
    within(editor_of('Vous êtes')) { fill_in 'Libellé du champ', with: 'Vous êtes un' }
    within(editor_of('Nom')) { expect(page).to have_css('td.target option', exact_text: 'Vous êtes un') }
    expect_the_state_of_a_reload

    within(editor_of('Vous êtes un')) { fill_in 'Options de la liste', with: "Particulier\nEntreprise\nAssociation" }
    within(editor_of('Société cotée')) { expect(page).to have_css('td.value option', exact_text: 'Association') }
    expect_the_state_of_a_reload

    within(editor_of('Effectif')) { check 'Ce nombre doit être positif', allow_label_click: true }
    within(editor_of('Raison sociale')) { expect(page).to have_css('.errors-summary') }
    expect_the_state_of_a_reload

    within(editor_of('Majeur')) { select_type_de_champ('Texte court') }
    within(editor_of('Nom')) { expect(page).to have_css('.errors-summary') }
    expect_the_state_of_a_reload
  end

  scenario 'editing top-level sections' do
    within(editor_of('Demandeur')) { fill_in 'Libellé du champ', with: 'Le demandeur' }
    within(editor_of('Raison sociale')) { expect(page).to have_css('td.target option[disabled]', exact_text: 'Le demandeur') }
    expect_the_state_of_a_reload

    within(editor_of('Entreprise')) { select 'Titre de niveau 1', from: 'Niveau du titre' }
    within(editor_of('Raison sociale')) { expect(page).to have_css('td.target option[disabled]', exact_text: 'Entreprise') }
    expect_the_state_of_a_reload
  end
end
