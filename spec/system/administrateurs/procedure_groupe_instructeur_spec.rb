# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'Manage procedure instructeurs', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs.default }
  let(:procedure) { create(:procedure) }
  let(:manager) { false }
  before do
    procedure.administrateurs_procedures.update_all(manager:)
    login_as administrateur.user, scope: :user
  end

  context 'is accessible via card' do
    let(:manager) { false }

    scenario 'it works' do
      visit admin_procedure_path(procedure)
      find('#groupe-instructeurs').click
      expect(page).to have_css("h1", text: "Gestion des instructeurs")
    end
  end

  context 'as admin from manager' do
    let(:manager) { true }

    scenario 'cannot add instructeur' do
      visit admin_procedure_groupe_instructeurs_path(procedure)

      expect(page).to have_css("#instructeur_emails[disabled=\"disabled\"]")
    end
  end

  context 'when adding a groupe instructeur via modal' do
    let(:procedure) { create(:procedure, :routee) }

    scenario 'creates a new groupe and redirects to its configuration page' do
      visit admin_procedure_groupe_instructeurs_path(procedure)

      click_button 'Ajouter un groupe'

      within('#modal-add-groupe') do
        expect(page).to have_button('Ajouter', disabled: true)

        fill_in 'Nouveau groupe', with: 'Départements hors IDF'

        expect(page).to have_button('Ajouter', disabled: false)

        click_button 'Ajouter'
      end

      expect(page).to have_content("a été créé")
      expect(page).to have_content("Départements hors IDF")
      expect(procedure.groupe_instructeurs.find_by(label: "Départements hors IDF")).to be_present
    end
  end

  context 'when adding instructeurs to a procedure without routing' do
    let(:procedure) { procedures.individual }

    scenario 'the submit button is enabled only while an email is selected' do
      visit admin_procedure_groupe_instructeurs_path(procedure)

      expect(page).to have_button('Ajouter', disabled: true)

      select_combobox('Emails', 'new_instructeur@gouv.fr', custom_value: true)
      expect(page).to have_button('Ajouter', disabled: false)

      click_button 'Supprimer new_instructeur@gouv.fr'
      expect(page).to have_button('Ajouter', disabled: true)

      # typed key by key and turned into a tag by the separator, without leaving the field
      find_field('Emails').send_keys('other_instructeur@gouv.fr', :space)
      expect(page).to have_button('Supprimer other_instructeur@gouv.fr')
      expect(page).to have_button('Ajouter', disabled: false)
    end
  end

  context 'when assigning instructeurs to every groupe of a routed procedure' do
    before_all { seed "cases/routage" }
    let(:procedure) { procedures.routee }

    scenario 'the submit button is enabled once an email is selected' do
      visit admin_procedure_groupe_instructeurs_path(procedure)

      within('#panel-bulk-add') do
        expect(page).to have_button('Ajouter dans tous les groupes', disabled: true)
        select_combobox('Emails', 'new_instructeur@gouv.fr', custom_value: true)
        expect(page).to have_button('Ajouter dans tous les groupes', disabled: false)
      end
    end
  end

  context 'when configuring the routing without a simple routable champ' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :integer_number }]) }

    scenario 'creates the placeholder groupes once the button is clicked' do
      visit options_admin_procedure_groupe_instructeurs_path(procedure)

      click_button 'Configurer le routage'

      expect(page).to have_content('Groupe 2 (à renommer et configurer)')
      expect(procedure.reload.routing_enabled).to be_truthy
    end
  end

  context 'when allowing self-managing instructeurs to add instructeurs from another email domain' do
    let(:procedure) { create(:procedure, instructeurs_self_management_enabled: true) }
    let(:label) { 'Autoriser les instructeurs à ajouter des adresses électroniques d’un autre domaine' }

    scenario 'the option can be checked then unchecked' do
      visit options_admin_procedure_groupe_instructeurs_path(procedure)

      check label, allow_label_click: true
      expect(page).to have_content('Les instructeurs peuvent ajouter des adresses électroniques d’un autre domaine.')
      expect(page).to have_checked_field(label)
      expect(procedure.reload.self_management_restricted_to_email_domain).to be(false)

      uncheck label, allow_label_click: true
      expect(page).to have_content('Les instructeurs ne peuvent ajouter que des adresses de leur domaine.')
      expect(page).to have_unchecked_field(label)
      expect(procedure.reload.self_management_restricted_to_email_domain).to be(true)
    end
  end
end
