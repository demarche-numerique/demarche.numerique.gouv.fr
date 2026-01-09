# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'Creating a new procedure', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs(:default_admin) }
  let(:procedure) do
    create(:procedure, :with_service, :with_instructeur,
      aasm_state: :publiee,
      published_at: Date.today,
      administrateurs: [administrateur],
      libelle: 'libellé de la procédure',
      path: 'libelle-de-la-procedure')
  end
  let!(:dossiers) do
    create(:dossier, :accepte, procedure: procedure, processed_at: 1.month.ago.to_date)
  end

  before { login_as administrateur.user, scope: :user }

  scenario "download archive" do
    visit admin_procedure_path(id: procedure.id)

    # check button
    expect(page).to have_selector('#archive-procedure')
    click_on "Télécharger"

    # check page loading
    expect(page).to have_content("Archives")

    # check archive
    expect {
      page.first(".fr-table .fr-btn").click
    }.to have_enqueued_job(ArchiveCreationJob).with(procedure, an_instance_of(Archive), administrateur)
    expect(page).to have_content("Votre demande a été prise en compte. Selon le nombre de dossiers, cela peut prendre de quelques minutes à plusieurs heures. Vous recevrez un courriel lorsque le fichier sera disponible.")
    expect(Archive.first.month).not_to be_nil

    # check exports
    click_on "Télécharger tous les dossiers"

    expect {
      within(:css, '#tabpanel-standard-panel') do
        choose "Fichier xlsx", allow_label_click: true
        click_on "Demander l’export"
      end
      expect(page).to have_content("Nous générons cet export. Veuillez revenir dans quelques minutes pour le télécharger.")
    }.to have_enqueued_job(ExportJob).with(an_instance_of(Export))
  end
end
