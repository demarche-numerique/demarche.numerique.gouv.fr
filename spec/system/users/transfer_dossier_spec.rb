# frozen_string_literal: true

describe 'Transfer dossier:' do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:procedure) { create(:simple_procedure) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_commentaires, user: user, procedure: procedure) }

  before do
    dossier
    login_as user, scope: :user
    visit dossiers_path
  end

  scenario 'the user can transfer dossier to another user' do
    within(:css, ".card", match: :first) do
      click_on 'Autres actions'
      click_on 'Transférer le dossier'
    end

    expect(page).to have_current_path(transferer_dossier_path(dossier))
    expect(page).to have_content("transférer le dossier en construction n° #{dossier.id}")
    fill_in 'Adresse électronique du compte destinataire', with: other_user.email
    click_on 'Envoyer la proposition de transfert'

    expect(page).to have_content('La proposition de transfert a bien été envoyée.')
    expect(page).to have_content('Proposition de transfert en cours')
    expect(page).to have_content("Vous avez envoyé une proposition de transfert de ce dossier à #{other_user.email}.")

    logout
    login_as other_user, scope: :user
    visit dossiers_path(statut: 'dossiers-transferes')

    expect(page).to have_content('Proposition de transfert')
    expect(page).to have_content("Proposition envoyée par #{user.email}.")
    click_on 'Accepter'

    expect(page).to have_current_path(dossiers_path)
    expect(page).to have_content('La proposition de transfert a été acceptée, le dossier est maintenant associé à votre compte.')
  end

  scenario 'the sender can cancel a pending transfer offer' do
    DossierTransfer.initiate(other_user.email, [dossier])
    visit dossiers_path

    click_on 'Annuler cette proposition'

    expect(page).to have_content('La proposition de transfert a été annulée.')
    expect(dossier.reload.transfer).to be_nil
  end

  scenario 'the pending offers tab counts dossiers awaiting transfer' do
    DossierTransfer.initiate(other_user.email, [dossier])
    logout
    login_as other_user, scope: :user
    visit dossiers_path(statut: 'dossiers-transferes')

    expect(page).to have_content('1 dossier en attente de transfert')
  end

  scenario 'a recipient is pointed to their pending offers from another tab' do
    create(:dossier, :en_construction, :with_individual, user: other_user, procedure: procedure)
    DossierTransfer.initiate(other_user.email, [dossier])
    logout
    login_as other_user, scope: :user

    visit dossiers_path(statut: 'dossiers-transferes')
    expect(page).not_to have_link('Voir la proposition en attente (1)')

    visit dossiers_path(statut: 'en-cours')
    click_on 'Voir la proposition en attente (1)'

    expect(page).to have_current_path(dossiers_path(statut: 'dossiers-transferes'))
  end

  scenario 'the recipient confirms before refusing an offer', js: true do
    DossierTransfer.initiate(other_user.email, [dossier])
    logout
    login_as other_user, scope: :user
    visit dossiers_path(statut: 'dossiers-transferes')

    accept_confirm('Êtes-vous sûr de vouloir refuser cette proposition de transfert ?') do
      click_on 'Refuser'
    end

    expect(page).to have_content('La proposition de transfert a été supprimée.')
    expect(dossier.reload.transfer).to be_nil
  end
end
