# frozen_string_literal: true

describe 'Limit a dossier link champ to some procedures', js: true do
  let(:administrateur) { administrateurs.default }
  let(:procedure) { create(:procedure, administrateurs: [administrateur], public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
  let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
  let(:linked_procedure) { procedures.individual }

  before do
    type_de_champ.update!(procedures_limit: '1')
    login_as administrateur.user, scope: :user
  end

  scenario 'the administrateur picks the procedures the champ accepts' do
    visit champs_admin_procedure_path(procedure)

    select_react_option("N°#{linked_procedure.id} - #{linked_procedure.libelle}", from: 'Sélectionnez la ou les démarches concernées')

    expect(page).to have_content('Formulaire enregistré')
    wait_until { type_de_champ.reload.dossier_link_procedure_ids == [linked_procedure.id] }
  end
end
