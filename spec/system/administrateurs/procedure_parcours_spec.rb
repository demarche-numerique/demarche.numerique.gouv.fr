# frozen_string_literal: true

describe 'As an administrateur I can see the possible paths through the form', js: true do
  include Logic

  let(:procedure) do
    create(:procedure, public_type_de_champs: [
      { type: :yes_no, libelle: 'Majeur', mandatory: true, stable_id: 1 },
      { type: :text, libelle: 'Tuteur', mandatory: true, condition: ds_eq(champ_value(1), constant(false)) },
    ])
  end
  let(:administrateur) { procedure.administrateurs.first }

  before { login_as administrateur.user, scope: :user }

  scenario 'from the champs editor' do
    visit champs_admin_procedure_path(procedure)
    click_on 'Voir les parcours possibles'

    expect(page).to have_content('Parcours possibles du formulaire')
    expect(page).to have_content('Majeur : Non')
    expect(page).to have_link('Tuteur')
    expect(page).to have_content('Majeur : Oui')
    expect(page).to have_content('Aucun champ supplémentaire')
  end

  scenario 'without conditions the link is not offered' do
    procedure.draft_revision.type_de_champs.last.update!(condition: nil)

    visit champs_admin_procedure_path(procedure)

    expect(page).to have_no_link('Voir les parcours possibles')
  end
end
