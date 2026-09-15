# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'As an administrateur I wanna clone a procedure', js: true do
  include ProcedureSpecHelper

  # procedure counts are asserted per admin: use the seeded blank
  # administrateur, who is guaranteed to own nothing
  let(:administrateur) { administrateurs.blank }

  before do
    create(:procedure, :with_service, :with_instructeur, :with_zone,
      aasm_state: :publiee,
      administrateurs: [administrateur],
      libelle: 'libellé de la procédure',
      path: 'libelle-de-la-procedure',
      published_at: Time.zone.now)
    login_as administrateur.user, scope: :user
  end
  context 'Visit all admin procedures and clone from this page' do
    let(:download_dir) { Pathname.new(Capybara.save_path) }
    let(:download_file_pattern) { download_dir.join('*.xlsx') }

    scenario do
      Dir[download_file_pattern].map { File.delete(_1) }
      visit all_admin_procedures_path

      click_on "Exporter les résultats"
      Timeout.timeout(Capybara.default_max_wait_time,
                      Timeout::Error,
                     "File download timeout! can't download procedure/all.xlsx") do
        sleep 0.1 until !Dir[download_file_pattern].empty?
      end

      expect(page).to have_content(Procedure.last.libelle)
      # the platform-wide list also shows seeded procedures: scope to our row
      # (re-found after the detail toggle re-renders it)
      within(find('tr', text: 'libellé de la procédure')) { find('.button_to>button').click }
      within(find('tr', text: 'libellé de la procédure')) { click_on 'Cloner' }
      check 'Instructeurs', allow_label_click: true
      click_on 'Cloner la démarche'
      expect(page).to have_current_path(%r{/admin/procedures/\d+\z})
      visit admin_procedures_path(statut: "brouillons")
      expect(page.find_by_id('procedures')['data-item-count']).to eq('1')
    end
  end
  context 'Cloning a procedure owned by the current admin' do
    scenario do
      visit admin_procedures_path
      expect(page.find_by_id('procedures')['data-item-count']).to eq('1')
      page.all('.card .dropdown .fr-btn').first.click
      page.all('.clone-btn').first.click
      check 'Instructeurs', allow_label_click: true
      click_on 'Cloner la démarche'
      expect(page).to have_current_path(%r{/admin/procedures/\d+\z})
      visit admin_procedures_path(statut: "brouillons")
      expect(page.find_by_id('procedures')['data-item-count']).to eq('1')
      click_on Procedure.last.libelle
      expect(page).to have_current_path(admin_procedure_path(id: Procedure.last))

      # select service
      find("#service .fr-btn").click
      click_on "Affecter"

      # select zone
      find("#zones .fr-btn").click
      check Zone.last.current_label, allow_label_click: true
      click_on 'Enregistrer'

      # then publish
      find('#publish-procedure-link').click
      expect(find_field('Lien de la démarche à diffuser aux usagers').value).to eq 'libelle-de-la-procedure-2'
      fill_in 'Lien de la démarche à diffuser aux usagers', with: 'libelle-de-la-procedure'
      expect(page).to have_content "Si vous publiez cette démarche, le lien ne pointera plus sur l’ancienne démarche."

      fill_in 'Où les usagers trouveront-ils le lien vers la démarche ?', with: 'http://some.website'
      click_on 'publish'

      page.refresh

      visit admin_procedures_path(statut: "archivees")
      expect(page.find_by_id('procedures')['data-item-count']).to eq('1')
      visit admin_procedures_path(statut: "brouillons")
      expect(page.find_by_id('procedures')['data-item-count']).to eq('0')
    end
  end
end
