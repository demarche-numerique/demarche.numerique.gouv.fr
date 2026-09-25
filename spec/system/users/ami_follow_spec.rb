# frozen_string_literal: true

describe 'The user, once their dossier is submitted', js: true do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, :for_individual) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, user:) }

  before do
    Flipper.enable(:ami_notifications, procedure)
    allow(Ami::RecipientFcHash).to receive(:call).and_return("abc123")
    allow_any_instance_of(Ami::Client).to receive(:configured?).and_return(true)
    allow(Ami::ConsentStatus).to receive(:call).and_return(:not_granted)
    allow(Ami::GrantConsent).to receive(:call).and_return(:granted)

    login_as user, scope: :user
    visit merci_dossier_path(dossier)
  end

  after { Flipper.disable(:ami_notifications, procedure) }

  scenario 'consents to follow their procedures in the app, without leaving the page' do
    expect(page).to have_button("Je souhaite suivre mes démarches sur #{Ami::APP_NAME}")

    click_on "Je souhaite suivre mes démarches sur #{Ami::APP_NAME}"

    expect(page).to have_text("Vous suivez vos démarches sur #{Ami::APP_NAME}")
    expect(page).not_to have_button("Je souhaite suivre mes démarches sur #{Ami::APP_NAME}")
    expect(page).to have_current_path(merci_dossier_path(dossier))
    expect(page).to have_text('Déposer un autre dossier')
  end

  # Le consentement passe par l'envoi de l'événement du dossier affiché.
  scenario 'sends the event of the dossier being viewed' do
    click_on "Je souhaite suivre mes démarches sur #{Ami::APP_NAME}"

    expect(page).to have_text("Vous suivez vos démarches sur #{Ami::APP_NAME}")
    expect(Ami::GrantConsent).to have_received(:call).with(dossier:, fc_hash: "abc123")
  end

  scenario 'reads what the app is about in a modal' do
    click_on 'Toutes les infos sur l’application'

    expect(page).to have_css('#ami-info-modal', visible: true)
    expect(page).to have_text('changer vos préférences de suivi des démarches')
  end
end
