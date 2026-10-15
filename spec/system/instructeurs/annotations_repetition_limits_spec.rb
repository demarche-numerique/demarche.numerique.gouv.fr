# frozen_string_literal: true

describe 'Private annotations with a limited repetition', js: true do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) do
    create(:procedure, :published, instructeurs: [instructeur], private_type_de_champs: [{ type: :repetition, mandatory: true, libelle: 'bloc annotation', children: [{ libelle: 'note' }] }]).tap do
      it.active_revision.private_root_type_de_champs.first.update!(limit_repetitions: '1', min_repetitions: '2')
    end
  end
  let(:dossier) { create(:dossier, :en_instruction, procedure:) }

  before { login_as(instructeur.user, scope: :user) }

  scenario 'the block error is cleared once a new row reaches the min' do
    visit annotations_privees_instructeur_dossier_path(procedure, dossier)
    expect(page).to have_content('« bloc annotation » doit contenir au minimum 2 élément(s)')

    click_on 'Ajouter un élément à « bloc annotation »'
    expect(page).to have_selector('.repetition-row', count: 2)

    expect(page).not_to have_content('« bloc annotation » doit contenir au minimum 2 élément(s)')
    expect(page).not_to have_selector('.editable-champ-repetition.fr-fieldset--error')
  end
end
