# frozen_string_literal: true

describe 'As an administrateur I switch a declarative procedure to the combined email', js: true do
  let(:administrateur) { administrateurs.default }
  let(:procedure) { procedures.individual }

  before do
    procedure.update!(declarative_with_state: :en_instruction)
    procedure.update!(combined_declarative_email: false)
    create(:email_depose, procedure:)

    login_as administrateur.user, scope: :user
  end

  scenario 'from the email templates screen' do
    visit admin_procedure_email_templates_path(procedure)

    expect(page).to have_css('.fr-notice--warning', text: 'nouvelle version')

    click_on 'En savoir plus'
    expect(page).to have_text('La nouvelle configuration des modèles d’email')

    click_on 'Passer à la nouvelle version'

    expect(page).to have_text('L’accusé de réception personnalisé a été supprimé')
    expect(page).to have_no_css('.fr-notice--warning')
    expect(page).to have_text(Emails::DeposeEtPasseEnInstruction::DISPLAYED_NAME)
    expect(procedure.reload.email_depose_templates).to be_empty
  end

  scenario 'warns before changing the declarative setting' do
    visit edit_admin_procedure_path(procedure)
    find('summary', text: 'Options avancées').click

    expect(page).to have_no_selector('.fr-notice--warning', visible: true)

    choose('Passage automatique au statut « accepté » (l’usager ne peut plus modifier son dossier)', allow_label_click: true)
    expect(page).to have_css('.fr-notice--warning', text: 'sera supprimé et adapté à ce nouveau paramétrage')

    choose('Passage automatique en instruction (l’usager ne peut plus modifier son dossier)', allow_label_click: true)
    expect(page).to have_no_selector('.fr-notice--warning', visible: true)
  end
end
