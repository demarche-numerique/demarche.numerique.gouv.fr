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
end
