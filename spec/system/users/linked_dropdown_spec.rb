# frozen_string_literal: true

describe 'linked dropdown lists', js: true do
  let(:password) { SECURE_PASSWORD }
  let!(:user) { create(:user, password: password) }

  let(:options) do
    [
      '--Primary 1--',
      'Secondary 1.1',
      'Secondary 1.2',
      '--Primary 2--',
      'Secondary 2.1',
      'Secondary 2.2',
      'Secondary 2.3',
    ]
  end

  let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs: [{ type: :linked_drop_down_list, libelle: 'linked dropdown', options: options, mandatory: mandatory }]) }

  let(:user_dossier) { user.dossiers.first }
  context 'not mandatory' do
    let(:mandatory) { false }
    scenario 'change primary value, secondary options are updated' do
      log_in(user.email, password, procedure)

      fill_individual
      expect(page).to have_select("linked dropdown", options: ['Sélectionnez', 'Primary 1', 'Primary 2'])

      # Select a primary value
      select('Primary 2', from: 'linked dropdown')

      # Secondary menu reflects chosen primary value
      expect(page).to have_select("Valeur secondaire dépendant de la première", options: ['Sélectionnez', 'Secondary 2.1', 'Secondary 2.2', 'Secondary 2.3'])

      # Select another primary value
      select('Primary 1', from: 'linked dropdown')

      # Secondary menu gets updated
      expect(page).to have_select("Valeur secondaire dépendant de la première", options: ['Sélectionnez', 'Secondary 1.1', 'Secondary 1.2'])
    end
  end

  context 'mandatory' do
    let(:mandatory) { true }

    scenario 'change primary value, secondary options are updated' do
      log_in(user.email, password, procedure)

      fill_individual
      expect(page).to have_select("linked dropdown", options: ['Sélectionnez', 'Primary 1', 'Primary 2'])

      # Select a primary value
      select('Primary 2', from: 'linked dropdown')

      # Secondary menu reflects chosen primary value
      expect(page).to have_select("Valeur secondaire dépendant de la première", options: ['Sélectionnez', 'Secondary 2.1', 'Secondary 2.2', 'Secondary 2.3'])

      # Select another primary value
      select('Primary 1', from: 'linked dropdown')

      # Secondary menu gets updated
      expect(page).to have_select("Valeur secondaire dépendant de la première", options: ['Sélectionnez', 'Secondary 1.1', 'Secondary 1.2'])
    end

    scenario 'missing value error references the contextual label' do
      log_in(user.email, password, procedure)

      fill_individual

      # Submit with nothing selected: error references the primary label.
      click_on 'Déposer le dossier'
      expect(page).to have_content('« linked dropdown » doit être rempli')

      # Select a primary value, leave the secondary empty, submit again:
      # error now references the secondary label.
      select('Primary 1', from: 'linked dropdown')
      click_on 'Déposer le dossier'
      expect(page).to have_content('« Valeur secondaire dépendant de la première » doit être rempli')

      # The error summary link and the secondary select both target the secondary input,
      # and the secondary select is associated to the error region for screen readers.
      champ = user_dossier.champ_data.first
      expect(page).to have_link('Valeur secondaire dépendant de la première', href: "##{champ.focusable_input_id(:secondary_value)}")
      expect(find("##{champ.focusable_input_id(:secondary_value)}")['aria-describedby']).to include(champ.error_id(:value))
    end
  end

  context 'accessibility' do
    let(:mandatory) { false }

    scenario 'the appearance of the secondary list is announced without moving the focus' do
      log_in(user.email, password, procedure)
      fill_individual

      primary_id = find_field('linked dropdown')['id']
      page.execute_script('document.getElementById(arguments[0]).focus()', primary_id)
      select('Primary 2', from: 'linked dropdown')

      expect(page).to have_select('Valeur secondaire dépendant de la première')
      expect(page).to have_css("##{primary_id}-aria-live[aria-live='polite']", text: 'Liste « Valeur secondaire dépendant de la première » disponible', visible: :all)
      expect(page.evaluate_script('document.activeElement.id')).to eq(primary_id)

      select('Secondary 2.1', from: 'Valeur secondaire dépendant de la première')
      expect(page).to have_css("##{primary_id}-aria-live", exact_text: '', visible: :all)
    end

    context 'in a repetition' do
      let(:procedure) do
        create(:procedure, :published, :for_individual, public_type_de_champs: [
          { type: :repetition, libelle: 'Enfants', children: [{ type: :linked_drop_down_list, libelle: 'linked dropdown', options: }] },
        ])
      end

      scenario 'the secondary list is named by its own label' do
        log_in(user.email, password, procedure)
        fill_individual

        select('Primary 2', from: 'linked dropdown')
        secondary = find_field('Valeur secondaire dépendant de la première')

        accessible_name = secondary['aria-labelledby'].split.map { find_by_id(it, visible: :all).text }.join(' ')
        expect(accessible_name).to include('Valeur secondaire dépendant de la première')
        expect(accessible_name).not_to include('linked dropdown')
      end
    end
  end

  private

  def log_in(email, password, procedure)
    visit "/commencer/#{procedure.path}"
    click_on 'J’ai déjà un compte'

    expect(page).to have_current_path(new_user_session_path)

    sign_in_with(email, password)

    expect(page).to have_current_path(commencer_path(path: procedure.path))
    click_on 'Commencer un dossier'

    find('label', text: "Pour vous").click
    expect(page).to have_content("Votre identité")
    expect(page).to have_current_path(identite_dossier_path(user_dossier))
  end

  def fill_individual
    find('label', text: "Pour vous").click
    within('.individual-infos') do
      fill_in('Prénom', with: 'prenom')
      fill_in('Nom', with: 'nom')
    end
    within "#identite-form" do
      click_on 'Continuer'
    end
    expect(page).to have_current_path(brouillon_dossier_path(user_dossier))
  end
end
