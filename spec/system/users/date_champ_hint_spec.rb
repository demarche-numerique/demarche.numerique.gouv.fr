# frozen_string_literal: true

describe 'Date champ format hint', js: true do
  before { login_as users.usager, scope: :user }

  scenario 'with a French browser on the English site, the hint keeps the browser date format after an autosave' do
    visit modifier_dossier_path(dossiers.en_construction, locale: :en)

    expect(page).to have_css('[data-controller="date-input-hint"]', text: 'Expected format: dd/mm/yyyy.', count: 1)

    fill_in('Date de début', with: '1999-03-05')
    blur
    expect(page).to have_css('input[type="date"][value="1999-03-05"]')

    expect(page).to have_text('modifications to submit')
    expect(page).to have_css('[data-controller="date-input-hint"]', text: 'Expected format: dd/mm/yyyy.', count: 1)
  end
end
