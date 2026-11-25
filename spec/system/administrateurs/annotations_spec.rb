# frozen_string_literal: true

describe 'As an administrateur I can edit annotation', js: true do
  include ActionView::RecordIdentifier
  let(:administrateur) { procedure.administrateurs.first }
  let(:procedure) { create(:procedure) }

  before do
    login_as administrateur.user, scope: :user
    visit annotations_admin_procedure_path(procedure)
  end

  scenario 'an annotation becomes a header section, holds other annotations, and the summary follows' do
    draft = procedure.draft_revision
    click_on 'Ajouter une annotation'

    select_type_de_champ('Titre de section')
    wait_until { draft.reload.private_type_de_champs.first&.header_section? }
    section = draft.private_type_de_champs.first
    expect(page).to have_link(section.libelle)

    # the first button adds within the section, empty so far
    within(find('.type-de-champ-add-button', match: :first)) {
      click_on 'Ajouter une annotation'
    }

    wait_until { draft.reload.type_de_champ(section.stable_id).children.size == 1 }
    expect(page).to have_css("##{dom_id(section, :types_de_champ_editor_block)} > li.type-de-champ", count: 1)

    # removing the section leaves what it holds in its place
    within("##{dom_id(section, :editor_error)}") do
      accept_alert do
        click_on 'Supprimer'
      end
    end

    wait_until { draft.reload.private_type_de_champs.map(&:header_section?) == [false] }
    expect(page).to have_no_link(section.libelle)
    expect(page).to have_css('.types-de-champ-editor > .types-de-champ-block > li.type-de-champ', count: 1)
  end
end
