# frozen_string_literal: true

# The "Accès direct" picker on the procedures lists (rendered from 4 procedures on).
describe 'Open a procedure from the direct access picker', js: true do
  context 'as an instructeur' do
    let(:instructeur) { instructeurs.default }
    let!(:procedures) { create_list(:procedure, 3, :published, instructeurs: [instructeur]) }
    let(:procedure) { procedures.last }

    before { login_as instructeur.user, scope: :user }

    scenario 'picking a procedure opens it' do
      visit instructeur_procedures_path

      select_react_option("n°#{procedure.id} - #{procedure.libelle}", from: 'Accès direct Sélectionnez une démarche')

      expect(page).to have_current_path(instructeur_procedure_path(procedure), ignore_query: true)
      expect(page).to have_content(procedure.libelle)
    end
  end

  context 'as an administrateur' do
    let(:administrateur) { administrateurs.default }
    let!(:procedures) { create_list(:procedure, 3, administrateurs: [administrateur]) }
    let(:procedure) { procedures.last }

    before { login_as administrateur.user, scope: :user }

    scenario 'picking a procedure opens it' do
      visit admin_procedures_path

      select_react_option("n°#{procedure.id} - #{procedure.libelle}", from: 'Accès direct Sélectionnez une démarche')

      expect(page).to have_current_path(admin_procedure_path(procedure), ignore_query: true)
      expect(page).to have_content(procedure.libelle)
    end
  end
end
