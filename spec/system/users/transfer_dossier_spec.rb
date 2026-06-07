# frozen_string_literal: true

describe 'Transfer dossier flow', js: true do
  let(:expediteur) { create(:user, email: 'expediteur@example.com') }
  let(:destinataire) { create(:user, email: 'destinataire@example.com') }
  let!(:dossier) { create(:dossier, :en_construction, user: expediteur) }

  describe 'sender flow' do
    before do
      DossierTransfer.initiate('destinataire@example.com', [dossier])
      login_as expediteur, scope: :user
    end

    it 'shows the new sender banner format on the dossier card' do
      visit dossiers_path
      expect(page).to have_content('Demande de transfert en cours')
      expect(page).to have_content('Vous avez envoyé une demande de transfert de ce dossier à destinataire@example.com.')
      expect(page).to have_link('Révoquer cette demande')
    end

    it 'allows revoking a sent transfer' do
      visit dossiers_path
      click_link 'Révoquer cette demande'
      expect(page).to have_current_path(dossiers_path)
      expect(dossier.reload.dossier_transfer_id).to be_nil
    end
  end

  describe 'recipient flow' do
    before do
      DossierTransfer.initiate('destinataire@example.com', [dossier])
      login_as destinataire, scope: :user
    end

    it 'shows the pending transfers banner on the dossiers index' do
      visit dossiers_path
      expect(page).to have_content('Demandes de transfert de dossier')
      expect(page).to have_link('Voir la demande en attente (1)')
    end

    it 'navigates to the transfer requests page' do
      visit dossiers_path
      click_link 'Voir la demande en attente (1)'
      expect(page).to have_current_path(transferts_path)
      expect(page).to have_content('Demandes de transfert')
      expect(page).to have_content('1 dossier en attente de transfert')
    end

    it 'accepts a transfer' do
      visit transferts_path
      find_link('Accepter').click
      expect(page).to have_current_path(dossiers_path)
      expect(dossier.reload.user).to eq(destinataire)
    end

    it 'refuses a transfer' do
      visit transferts_path
      accept_confirm { click_link 'Refuser' }
      expect(page).to have_current_path(dossiers_path)
      expect(dossier.reload.dossier_transfer_id).to be_nil
    end

    it 'renders as a dedicated screen while keeping accessibility landmarks' do
      visit transferts_path

      expect(page).not_to have_selector('header.fr-header')
      expect(page).to have_selector('.fr-skiplinks a[href="#contenu"]', visible: :all)
      expect(page).to have_selector('main#contenu')
    end
  end
end
