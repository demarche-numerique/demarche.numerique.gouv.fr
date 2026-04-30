# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'As an administrateur, I want to manage the procedure’s attestation', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs(:default_admin) }

  before do
    login_as(administrateur.user, scope: :user)
  end

  def find_attestation_card(v2: true, with_nested_selector: nil)
    attestation_path = v2 ? edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :acceptation)
                          : edit_admin_procedure_attestation_template_path(procedure)

    full_selector = [
      "a[href=\"#{attestation_path}\"]",
      with_nested_selector,
    ].compact.join(" ")
    page.find(full_selector)
  end

  context 'Update or disable v1' do
    let(:procedure) do
      create(:procedure, :published,
        administrateurs: [administrateur],
        attestation_acceptation_template: build(:attestation_template))
    end

    scenario do
      visit admin_procedure_path(procedure)

      within find_attestation_card(v2: false) do
        expect(page).to have_content('Activée')
        click
      end

      fill_in "Titre de l’attestation", with: 'BOOM'
      fill_in "Contenu de l’attestation", with: 'BOOM'
      click_on 'Enregistrer'

      page.find(".alert-success", text: "Le modèle de l’attestation a bien été modifié")

      # now process to disable attestation
      find('.toggle-switch-control').click
      click_on 'Enregistrer'
      page.find(".alert-success", text: "Le modèle de l’attestation a bien été modifié")

      # check attestation is now disabled
      visit admin_procedure_path(procedure)

      find_attestation_card(v2: false, with_nested_selector: ".fr-badge")
      expect(page).to have_content('Désactivée')
    end

    scenario 'upload logo and signature' do
      visit admin_procedure_path(procedure)

      within find_attestation_card(v2: false) do
        expect(page).to have_content('Activée')
        click
      end

      attestation = procedure.attestation_acceptation_template

      expect(page).to have_text("Logo de l’attestation")
      find('input[type=file]', match: :first).attach_file(Rails.root.join('spec/fixtures/files/logo_test_procedure.png'))

      expect(page).to have_text("Tampon de l’attestation")
      all('input[type=file]').last.attach_file(Rails.root.join('spec/fixtures/files/white.png'))

      click_on 'Enregistrer'
      expect(page).to have_text("Le modèle de l’attestation a bien été modifié")

      # Verify attachments are persisted
      attestation.reload
      expect(attestation.logo).to be_attached
      expect(attestation.signature).to be_attached
      expect(attestation.logo.filename.to_s).to eq('logo_test_procedure.png')
      expect(attestation.signature.filename.to_s).to eq('white.png')

      # Test de suppression du logo
      visit admin_procedure_path(procedure)
      within find_attestation_card(v2: false) do
        click
      end

      click_on 'Supprimer le fichier logo_test_procedure.png'

      wait_until { !attestation.reload.logo.attached? }
      expect(attestation.logo.attached?).to be(false)

      # Test de suppression de la signature
      click_on 'Supprimer le fichier white.png'

      wait_until { !attestation.reload.signature.attached? }
      expect(attestation.signature.attached?).to be(false)
    end
  end

  context 'Update attestation v2' do
    let(:procedure) do
      create(:procedure, :published,
        administrateurs: [administrateur],
        libelle: 'libellé de la procédure',
        path: 'libelle-de-la-procedure')
    end

    scenario do
      visit admin_procedure_path(procedure)
      find_attestation_card(with_nested_selector: ".fr-badge")

      find_attestation_card.click

      expect(procedure.reload.attestation_templates.v2).to be_empty

      expect(page).to have_css("label", text: "Logo additionnel")

      fill_in "Intitulé de votre institution", with: "System Test"
      fill_in "Intitulé de la direction", with: "The boss"

      attestation = nil
      wait_until {
        attestation = procedure.reload.attestation_templates.v2.draft.first
        attestation.present?
      }
      expect(page).to have_content("Attestation enregistrée")
      expect(attestation.label_logo).to eq("System Test")
      expect(attestation.activated?).to be_truthy

      click_on "date de décision"

      # TODO find a way to fill in tiptap

      attach_file('Tampon ou signature', Rails.root + 'spec/fixtures/files/white.png')
      wait_until { attestation.reload.signature.attached? }

      fill_in "Contenu du pied de page", with: "Footer"

      wait_until {
        body = JSON.parse(attestation.reload.tiptap_body)
        first_content = body.dig("content").first&.dig("content")&.first&.dig("content")&.first&.dig("content")

        first_content == [
          { "type" => "mention", "attrs" => { "id" => "dossier_processed_at", "label" => "date de décision" } }, # added by click above
          { "type" => "text", "text" => " " },
          { "type" => "mention", "attrs" => { "id" => "dossier_service_name", "label" => "nom du service" } }, # defaut initial content
        ]
      }

      find("label", text: /à la charte de l’état/).click

      expect(page).not_to have_css("label", text: "Logo additionnel", visible: true)
      expect(page).not_to have_css("label", text: "Intitulé du logo", visible: true)

      attach_file('Logo', Rails.root + 'spec/fixtures/files/black.png')

      wait_until {
        attestation.reload.logo.attached? && attestation.signature.attached? && !attestation.official_layout?
      }

      fill_in "Contenu du pied de page", with: ["line1", "line2", "line3", "line4"].join("\n")
      # FIXME we should get line1\nline2\nline3line4 instead of line1\nline2\nline3\nline4 because row is set to 3
      expect(page).to have_field("Contenu du pied de page", with: "line1\nline2\nline3\nline4")

      click_on "Publier"
      expect(attestation.reload).to be_published
      expect(page).to have_text("L’attestation a été publiée")

      fill_in "Intitulé de la direction", with: "plop"
      accept_alert do
        click_on "Publier les modifications"
      end
      expect(procedure.reload.attestation_acceptation_template.label_direction).to eq("plop")
      expect(page).to have_text(/La nouvelle version de l’attestation/)
    end

    context "tag in error" do
      before do
        tdc = procedure.active_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
        procedure.publish_revision!(procedure.administrateurs.first)

        attestation = procedure.attestation_templates.build(version: 2, json_body: AttestationTemplate::TIPTAP_BODY_DEFAULT, label_logo: "test", kind: "acceptation")
        attestation.json_body["content"] << { type: :mention, attrs: { id: "tdc#{tdc.stable_id}", label: tdc.libelle } }
        attestation.save!

        procedure.draft_revision.remove_type_de_champ(tdc)
      end

      scenario do
        visit edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :acceptation)
        expect(page).to have_content("Le champ « Contenu de l’attestation » contient la balise \"age\"")

        click_on "date de décision"

        expect(page).to have_content("Attestation en erreur")
        expect(page).to have_content("Le champ « Contenu de l’attestation » contient la balise \"age\"")

        page.execute_script("document.getElementById('attestation_template_tiptap_body').type = 'text'")
        fill_in "attestation_template[tiptap_body]", with: AttestationTemplate::TIPTAP_BODY_DEFAULT.to_json

        expect(page).to have_content("Attestation enregistrée")
        expect(page).not_to have_content("Attestation en erreur")
        expect(page).not_to have_content("Le champ « Contenu de l’attestation » contient la balise \"age\"")
      end
    end
  end
end
