# frozen_string_literal: true

describe 'dropdown list with other option activated', js: true do
  let(:password) { SECURE_PASSWORD }
  let!(:user) { create(:user, password: password) }

  let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :drop_down_list, libelle: 'simple dropdown other', options: options + [:other] }]) }

  let(:user_dossier) { user.dossiers.first }

  before do
    login_as(user, scope: :user)
    visit "/commencer/#{procedure.path}?locale=fr"
    click_on 'Commencer la démarche'
  end
  context 'with radios' do
    let(:options) do
      [
        '--Primary 1--',
        'Secondary 1.1',
        'Secondary 1.2',
      ]
    end

    scenario "Select other, fill it, then switch back saves correctly", :aggregate_failures do
      fill_individual

      choose I18n.t('shared.champs.drop_down_list.other'), allow_label_click: true
      expect(page).to have_selector('.drop_down_other', visible: true)

      fill_in(I18n.t('shared.champs.drop_down_list.other_label'), with: "My choice")

      wait_until { user_dossier.reload.root_public_champs.first.value == "My choice" }
      expect(user_dossier.root_public_champs.first.value).to eq("My choice")

      choose "Secondary 1.1", allow_label_click: true

      wait_until { user_dossier.reload.root_public_champs.first.value == "Secondary 1.1" }
      expect(user_dossier.root_public_champs.first.value).to eq("Secondary 1.1")
    end
  end

  context 'with select' do
    let(:options) do
      [
        '--Primary 1--',
        'Secondary 1.1',
        'Secondary 1.2',
        'Secondary 1.3',
        'Secondary 1.4',
        'Secondary 1.5',
        'Secondary 1.6',
      ]
    end

    scenario 'with a select and other, selecting a value save it (avoid hidden other_value to be sent)' do
      fill_individual

      expect(page).not_to have_selector(".drop_down_other input")
      select(I18n.t('shared.champs.drop_down_list.other'))
      find(".drop_down_other input", visible: true)

      select("Secondary 1.2")
      expect(page).to have_selector(".autosave-status.succeeded", visible: true)

      wait_until { user_dossier.reload.root_public_champs.first.value == "Secondary 1.2" }
      expect(user_dossier.root_public_champs.first.value).to eq("Secondary 1.2")
    end
  end

  private

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

describe 'multiple dropdown tag removal', js: true do
  let(:user) { create(:user) }
  let(:options) { (1..7).map { "Option #{_1}" } }
  let(:procedure) do
    create(:procedure, :published, :for_individual, types_de_champ_public: [
      { type: :multiple_drop_down_list, libelle: 'Multi choix', drop_down_options: options },
    ])
  end

  before do
    login_as(user, scope: :user)
    visit "/commencer/#{procedure.path}?locale=fr"
    click_on 'Commencer la démarche'
    find('label', text: "Pour vous").click
    within('.individual-infos') do
      fill_in('Prénom', with: 'prenom')
      fill_in('Nom', with: 'nom')
    end
    within "#identite-form" do
      click_on 'Continuer'
    end
  end

  scenario 'clicking on a tag removes the selection' do
    select_autocomplete('Multi choix', 'Option 1')
    select_autocomplete('Multi choix', 'Option 2')

    expect(page).to have_css('.fr-tag', text: 'Option 1')
    expect(page).to have_css('.fr-tag', text: 'Option 2')

    find('.fr-tag', text: 'Option 1').click
    expect(page).not_to have_css('.fr-tag', text: 'Option 1')
    expect(page).to have_css('.fr-tag', text: 'Option 2')
  end

  scenario 'tag is a single focusable button with proper aria-label' do
    select_autocomplete('Multi choix', 'Option 1')
    select_autocomplete('Multi choix', 'Option 2')

    expect(page).to have_css('.fr-tag', text: 'Option 1')

    tag_button = find('button.fr-tag--dismiss[aria-label="Supprimer Option 1"]')
    expect(tag_button.tag_name).to eq('button')
    expect(tag_button['aria-label']).to eq('Supprimer Option 1')

    tag_button.click
    expect(page).not_to have_css('.fr-tag', text: 'Option 1')
    expect(page).to have_css('.fr-tag', text: 'Option 2')
  end

  scenario 'keyboard navigation: tab moves between tags, no double focus' do
    select_autocomplete('Multi choix', 'Option 1')
    select_autocomplete('Multi choix', 'Option 2')
    select_autocomplete('Multi choix', 'Option 3')

    tag1 = find('button.fr-tag--dismiss[aria-label="Supprimer Option 1"]')
    tag1.send_keys(:tab)
    expect(page.evaluate_script('document.activeElement.getAttribute("aria-label")')).to eq('Supprimer Option 2')

    find('button.fr-tag--dismiss[aria-label="Supprimer Option 2"]').send_keys(:tab)
    expect(page.evaluate_script('document.activeElement.getAttribute("aria-label")')).to eq('Supprimer Option 3')
  end
end
