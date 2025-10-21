# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'Creating a new procedure', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs.default }

  before do
    login_as administrateur.user, scope: :user
    visit root_path
  end

  scenario 'an admin can create a new procedure from scratch' do
    expect(page).to have_selector('#new-procedure')
    find('#new-procedure').click

    expect(page).to have_current_path(new_from_existing_admin_procedures_path)
    click_on 'Créer une nouvelle démarche de zéro'
    expect(find('#procedure_identity_kind_individual')).to be_checked
    expect(find('#procedure_identity_kind_personne_morale')).not_to be_checked
    fill_in 'procedure_duree_conservation_dossiers_dans_ds', with: '3'
    click_on 'Créer la démarche'

    fill_in_dummy_procedure_details
    click_on 'Créer la démarche'

    expect(page).to have_current_path(champs_admin_procedure_path(Procedure.last))
  end

  context 'with an empty procedure' do
    let(:procedure) { create(:procedure, :with_service, administrateur: administrateur) }

    scenario 'an admin can add types de champs' do
      visit champs_admin_procedure_path(procedure)

      add_champ
      hide_autonotice_message

      fill_in 'Libellé du champ', with: 'libelle de champ'
      blur
      expect(page).to have_content('Formulaire enregistré')
      expect(page).to have_selector('select > optgroup', count: 8)

      within(find('.type-de-champ-add-button', match: :first)) {
        add_champ
      }
      expect(page).to have_selector('.type-de-champ', count: 1)
    end

    scenario 'a warning is displayed when creating an invalid procedure' do
      visit champs_admin_procedure_path(procedure)

      # Add an empty repetition type de champ
      add_champ
      hide_autonotice_message
      select('Bloc répétable', from: 'Type de champ')
      fill_in 'Libellé du champ', with: 'libellé de champ'
      blur
      expect(page).to have_content('Formulaire enregistré')

      click_link procedure.libelle
      expect(page).to have_current_path(admin_procedure_path(procedure))

      champs_card = find('.fr-tile', text: 'Champs du formulaire')
      expect(champs_card).to have_selector('.fr-badge--error')
      expect(champs_card).to have_content('À modifier')
    end
  end
end
