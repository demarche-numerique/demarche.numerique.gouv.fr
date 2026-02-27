# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'Manage procedure instructeurs', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs(:default_admin) }
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
end
