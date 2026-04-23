# frozen_string_literal: true

describe 'user dossiers list', js: true do
  let(:user) { create(:user) }

  before { login_as user, scope: :user }

  describe 'dossiers list' do
    before { create_list(:dossier, 3, :en_construction, user: user) }

    it 'shows search and filter UI' do
      visit dossiers_path
      expect(page).to have_selector('input[name=search]')
      expect(page).to have_button(text: /Filtrer les dossiers/i)
    end
  end

  describe 'search result page' do
    let!(:target_dossier) { create(:dossier, :en_construction, user: user) }

    before { create_list(:dossier, 5, :en_construction, user: user) }

    it 'shows result title and back link' do
      visit dossiers_path(search: target_dossier.id.to_s)

      expect(page).to have_content('Résultat de la recherche pour')
      expect(page).to have_link('← Mes dossiers', href: dossiers_path)
    end
  end

  describe 'corbeille link' do
    it 'is hidden when no hidden dossiers' do
      create_list(:dossier, 2, :en_construction, user: user)
      visit dossiers_path

      expect(page).not_to have_css('.mes-dossiers-header__corbeille')
    end

    it 'is visible with count when hidden dossiers exist' do
      create(:dossier, :en_construction, :hidden_by_user, user: user)
      create(:dossier, :en_construction, user: user)
      visit dossiers_path

      expect(page).to have_css('.mes-dossiers-header__corbeille')
      expect(page).to have_text('Corbeille (1)')
    end

    it 'navigates to the trash page' do
      create(:dossier, :en_construction, :hidden_by_user, user: user)
      visit dossiers_path
      find('.mes-dossiers-header__corbeille').click

      expect(page).to have_current_path(trash_path)
      expect(page).to have_content('Corbeille')
      expect(page).to have_link('← Mes dossiers')
      expect(page).to have_link('Historique des dossiers supprimés')
    end
  end

  describe 'trash page' do
    it 'lists only hidden dossiers' do
      hidden = create(:dossier, :en_construction, :hidden_by_user, user: user)
      visible = create(:dossier, :en_construction, user: user)

      visit trash_path

      expect(page).to have_content(hidden.id)
      expect(page).not_to have_content(visible.id)
    end

    it 'does not show search or filter UI' do
      create_list(:dossier, 10, :en_construction, :hidden_by_user, user: user)
      visit trash_path

      expect(page).not_to have_selector('input[name=search]')
      expect(page).not_to have_button(text: /Filtrer les dossiers/i)
    end

    it 'links to the deleted dossiers history page' do
      create(:dossier, :en_construction, :hidden_by_user, user: user)
      visit trash_path
      click_link 'Historique des dossiers supprimés'

      expect(page).to have_current_path(deleted_dossiers_path)
    end
  end

  describe 'filter panel' do
    before { create_list(:dossier, 6, :en_construction, user: user) }

    it 'opens the filter modal when clicking the filter button' do
      visit dossiers_path
      expect(page).not_to have_selector('#dossiers-filter-modal[open]')
      click_button(text: /Filtrer les dossiers/i)
      expect(page).to have_selector('#dossiers-filter-modal[open]')
    end
  end

  describe 'active filter with no result' do
    before { create_list(:dossier, 10, :en_construction, user: user) }

    it 'renders the empty state without error' do
      visit dossiers_path(state: ['accepte'])
      expect(page).to have_content(/0 dossier|aucun dossier|Aucun résultat|Aucun dossier ne correspond/i)
    end
  end

  describe 'active filter chips' do
    pending "TODO: chip removal requires JS interaction inside DSFR modal; filter logic covered by spec/controllers/users/dossiers_controller_spec.rb GET #index"
  end

  describe 'reset filters' do
    pending "TODO: reset requires JS interaction inside DSFR modal; filter logic covered by spec/controllers/users/dossiers_controller_spec.rb GET #index"
  end
end
