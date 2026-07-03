# frozen_string_literal: true

describe 'Instructeur viewing a linked dossier they cannot access:', js: true do
  let(:instructeur) { create(:instructeur) }
  let(:other_procedure) { create(:procedure, :published) }
  let(:linked_dossier) { create(:dossier, :en_construction, procedure: other_procedure) }
  let(:procedure) { create(:procedure, :published, instructeurs: [instructeur], types_de_champ_public: [{ type: :dossier_link }]) }
  let(:dossier) { create(:dossier, :en_instruction, procedure:) }

  before do
    dossier.project_champs_public.find(&:dossier_link?).update(value: linked_dossier.id)
    login_as(instructeur.user, scope: :user)
    visit instructeur_dossier_path(procedure, dossier)
  end

  # Le contenu de la modale (emails admin / service) est couvert par
  # Dossiers::NoAccessToDossierComponent ; on vérifie ici l'intégration :
  # le champ inaccessible rend le composant et la modale s'ouvre au clic.
  scenario 'the dossier number link opens the modal explaining the lack of access' do
    modal_id = "modal-no-access-to-dossier-#{linked_dossier.id}"

    expect(page).to have_selector("##{modal_id}", visible: false)
    click_on "Dossier n° #{linked_dossier.id}"

    expect(page).to have_selector("##{modal_id}", visible: true)
    within "##{modal_id}" do
      expect(page).to have_text("Vous n’avez pas accès à ce dossier")
    end
  end
end
