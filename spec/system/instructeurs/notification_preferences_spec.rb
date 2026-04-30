# frozen_string_literal: true

describe 'Instructeur notification preferences:', js: true do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, instructeurs: [instructeur]) }

  before do
    login_as instructeur.user, scope: :user
    visit notification_preferences_instructeur_procedure_path(procedure)
  end

  scenario 'toggling instant_email_new_message reveals the followed-dossiers notice' do
    notice = ".fr-notice--info"

    expect(page).to have_css(notice, visible: :hidden, text: 'Vous devez impérativement')
    expect(page).to have_no_css(notice, visible: true)

    find('label', text: 'Recevoir un email à chaque message envoyé par l’usager').click

    expect(page).to have_css(notice, visible: true, text: 'Vous devez impérativement')

    find('label', text: 'Recevoir un email à chaque message envoyé par l’usager').click

    expect(page).to have_no_css(notice, visible: true)
  end
end
