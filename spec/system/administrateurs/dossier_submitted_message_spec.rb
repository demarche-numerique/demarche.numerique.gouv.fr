# frozen_string_literal: true

describe 'As an administateur i can setup a DossierSubmittedMessage' do
  let(:procedure) { create(:procedure, :for_individual, administrateurs: [administrateur], instructeurs: [create(:instructeur)]) }
  let(:administrateur) { create(:administrateur, user: create(:user)) }
  before { login_as administrateur.user, scope: :user }
  scenario 'Dossier submitted message' do
    visit edit_admin_procedure_dossier_submitted_message_path(procedure)
    fill_in "Message affiché après l’envoi du dossier", with: 'ok'
    click_on 'Enregistrer'
    expect(page).to have_content("Les informations de fin de dépot ont bien été sauvegardées.")
  end
end
