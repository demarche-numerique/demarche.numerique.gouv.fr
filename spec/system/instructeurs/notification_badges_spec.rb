# frozen_string_literal: true

describe "Instructeur notification badges:", js: true do
  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:dossier_with_message) { dossiers.en_construction }
  let(:dossier_with_message_and_annotation) { dossiers.en_instruction }

  before do
    instructeur.followed_dossiers << [dossier_with_message, dossier_with_message_and_annotation]
    create(:dossier_notification, instructeur:, dossier: dossier_with_message, notification_type: :message)
    create(:dossier_notification, instructeur:, dossier: dossier_with_message_and_annotation, notification_type: :message)
    create(:dossier_notification, instructeur:, dossier: dossier_with_message_and_annotation, notification_type: :annotation_instructeur)

    login_as instructeur.user, scope: :user
  end

  scenario "the procedures list announces how many dossiers have something unread, then what is unread" do
    visit instructeur_procedures_path

    within("#procedure-#{procedure.id}-notifications") do
      expect(page).to have_css(".fr-sr-only", text: "2 dossiers avec au moins un message non lu", exact_text: true, visible: :all)
      expect(page).to have_css(".fr-sr-only", text: "1 dossier avec au moins une annotation privée non lue", exact_text: true, visible: :all)
      expect(page).to have_css("[aria-hidden=true]", text: "Message", exact_text: true)

      click_on "Détails des notifications"

      expect(find("h5", text: "Message")).to have_css(".fr-sr-only", text: "non lu", exact_text: true, visible: :all)
      expect(find("h5", text: "Annotation privée")).to have_css(".fr-sr-only", text: "non lue", exact_text: true, visible: :all)
    end
  end

  scenario "the dossiers table announces what is unread" do
    visit instructeur_procedure_path(procedure, statut: "suivis")

    within(find(".dossiers-table a", text: dossier_with_message.id.to_s, exact_text: true).ancestor("td")) do
      expect(page).to have_css(".fr-badge", text: "Message")
      expect(page).to have_css(".fr-sr-only", text: "non lu", exact_text: true, visible: :all)
    end

    within(find(".dossiers-table a", text: dossier_with_message_and_annotation.id.to_s, exact_text: true).ancestor("td")) do
      expect(page).to have_css(".fr-badge", text: "Annotation privée")
      expect(page).to have_css(".fr-sr-only", text: "non lue", exact_text: true, visible: :all)
    end
  end
end
