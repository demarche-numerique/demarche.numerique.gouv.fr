# frozen_string_literal: true

describe 'Instructeur viewing a linked dossier they instruct:', js: true do
  let(:instructeur) { create(:instructeur) }
  let(:linked_service) { create(:service, nom: "ARS La Réunion") }
  let(:linked_procedure) { create(:procedure, :published, libelle: "Culture et Santé", service: linked_service, instructeurs: [instructeur]) }
  let(:linked_dossier) { create(:dossier, :en_construction, procedure: linked_procedure) }
  let(:procedure) { create(:procedure, :published, instructeurs: [instructeur], public_type_de_champs: [{ type: :dossier_link }]) }
  let(:dossier) { create(:dossier, :en_instruction, procedure:) }

  before do
    dossier.champ_data.find { it.is_a?(Champs::DossierLinkChamp) }.update!(value: linked_dossier.id)
    linked_procedure.update!(libelle: "Nouvel intitulé")
    linked_service.update!(nom: "Nouveau service")
    login_as(instructeur.user, scope: :user)
    visit instructeur_dossier_path(procedure, dossier)
  end

  scenario 'the data card keeps the original procedure title and service name and links to the dossier' do
    within ".dossier_link .external-champ" do
      expect(page).to have_text("Source : #{APPLICATION_NAME}")
      expect(page).to have_css("dt", text: "N° dossier")
      expect(page).to have_css("dt", text: "Date de dépôt du dossier")
      expect(page).to have_css("dd", text: linked_dossier.depose_at.to_date.strftime("%d/%m/%Y"))
      expect(page).to have_css("dt", text: "Intitulé de la démarche")
      expect(page).to have_css("dd", text: "Culture et Santé")
      expect(page).to have_css("dt", text: "Service porteur de la démarche")
      expect(page).to have_css("dd", text: "ARS La Réunion")
      expect(page).to have_link("Dossier n° #{linked_dossier.id}", href: instructeur_dossier_path(linked_procedure, linked_dossier))
    end

    expect(page).to be_axe_clean.within(".dossier_link")

    new_window = window_opened_by { click_on "Dossier n° #{linked_dossier.id}" }
    within_window(new_window) do
      expect(page).to have_current_path(instructeur_dossier_path(linked_procedure, linked_dossier))
    end
  end
end
