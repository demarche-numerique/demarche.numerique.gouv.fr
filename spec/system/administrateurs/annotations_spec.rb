# frozen_string_literal: true

describe 'As an administrateur I can edit annotation', js: true do
  include ActionView::RecordIdentifier
  let(:administrateur) { procedure.administrateurs.first }
  let(:procedure) { create(:procedure) }

  before do
    login_as administrateur.user, scope: :user
    visit annotations_admin_procedure_path(procedure)
  end

  scenario 'with private tdc, having invalid order, it pops up errors summary' do
    click_on 'Ajouter une annotation'

    select('Titre de section', from: 'Type de champ')
    wait_until { procedure.reload.active_revision.root_private_types_de_champ.first&.type_champ == TypeDeChamp.type_champs.fetch(:header_section) }
    first_header = procedure.active_revision.root_private_types_de_champ.first
    select('Titre de niveau 1', from: dom_id(first_header, :header_section_level))

    within(find('.type-de-champ-add-button', match: :first)) {
      click_on 'Ajouter une annotation'
    }

    wait_until { procedure.reload.active_revision.root_private_types_de_champ.count == 2 }
    second_header = procedure.active_revision.root_private_types_de_champ.last
    select('Titre de section', from: dom_id(second_header, :type_champ))
    wait_until { procedure.reload.active_revision.root_private_types_de_champ.last&.type_champ == TypeDeChamp.type_champs.fetch(:header_section) }
    select('Titre de niveau 2', from: dom_id(second_header, :header_section_level))

    within(".types-de-champ-block li:first-child") do
      accept_alert do
        click_on 'Supprimer'
      end
    end

    expect(page).to have_content("devrait être précédé d’un titre de niveau 1")

    # check summary
    procedure.reload.active_revision.root_private_types_de_champ.each do |header_section|
      expect(page).to have_link(header_section.libelle)
    end
  end
end
