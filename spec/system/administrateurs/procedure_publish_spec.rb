# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'Publishing a procedure', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs.default }
  let(:other_administrateur) { create(:administrateur) }

  let(:instructeurs) { [administrateur.user.instructeur] }
  let!(:procedure) do
    create(:procedure_with_dossiers,
      :with_path,
      :with_type_de_champ,
      :with_service,
      :with_zone,
      instructeurs: instructeurs,
      administrateur: administrateur)
  end
  let!(:other_procedure) do
    create(:procedure_with_dossiers,
      :published,
      :with_path,
      :with_type_de_champ,
      :with_service,
      :with_zone,
      instructeurs: instructeurs,
      administrateur: other_administrateur)
  end

  before do
    login_as administrateur.user, scope: :user
  end

  context 'when using a deprecated back-office URL' do
    scenario 'the admin is redirected to the draft procedure' do
      visit admin_procedures_draft_path
      expect(page).to have_current_path(admin_procedures_path(statut: "brouillons"))
    end

    scenario 'the admin is redirected to the archived procedures' do
      visit admin_procedures_archived_path
      expect(page).to have_current_path(admin_procedures_path(statut: "archivees"))
    end
  end

  context 'when a procedure isn’t published yet' do
    scenario 'an admin can publish it' do
      visit admin_procedure_path(procedure)
      find('#publish-procedure-link').click

      expect(find_field('procedure_path').value).to eq procedure.path
      fill_in 'procedure[lien_site_web]', with: 'http://some.website'
      within('form') { click_on 'Publier' }

      expect(page).to have_text('Votre démarche est désormais publiée !')
      expect(page).to have_button(title: 'Copiez le lien de la procédure')
    end

    context 'when the procedure has invalid champs' do
      let!(:procedure) do
        create(:procedure,
               :with_path,
               :with_service,
               :with_zone,
               instructeurs: instructeurs,
               administrateur: administrateur,
               types_de_champ_public: [{ type: :repetition, libelle: 'Enfants', children: [] }, { type: :drop_down_list, libelle: 'Civilité' }],
               types_de_champ_private: [{ type: :drop_down_list, libelle: 'Civilité' }])
      end

      before do
        drop_down = procedure.draft_revision.root_public_types_de_champ.find(&:any_drop_down_list?)
        drop_down.record.update!(drop_down_options: [])
        drop_down = procedure.draft_revision.root_private_types_de_champ.find(&:any_drop_down_list?)
        drop_down.record.update!(drop_down_options: [])
      end

      scenario 'an error message prevents the publication' do
        visit admin_procedure_path(procedure)

        expect(page).to have_content('Des problèmes empêchent la publication de la démarche')
        expect(page).to have_content("Enfants doit comporter au moins un champ répétable")
        expect(page).to have_content("Civilité doit comporter au moins un choix sélectionnable")

        visit admin_procedure_publication_path(procedure)
        expect(find_field('procedure_path').value).to eq procedure.path
        fill_in 'procedure[lien_site_web]', with: 'http://some.website'

        expect(page).to have_button('Publier', disabled: true)
      end
    end

    context 'when the procedure has the same path as another procedure from another admin ' do
      scenario 'an error message prevents the publication' do
        visit admin_procedure_publication_path(procedure)
        fill_in 'procedure_path', with: other_procedure.path

        expect(page).to have_content 'vous devez la modifier afin de pouvoir publier votre démarche'

        fill_in 'procedure[lien_site_web]', with: 'http://some.website'
        within('form') { click_on 'Publier' }

        expect(page).to have_text('Le champ « Lien public » est déjà utilisé par une démarche.')
      end
    end
  end

  context 'when a procedure is closed' do
    let!(:procedure) do
      create(:procedure_with_dossiers,
        :closed,
        :with_path,
        :with_type_de_champ,
        :with_service,
        instructeurs: instructeurs,
        administrateur: administrateur)
    end

    scenario 'an admin can publish it again' do
      visit admin_procedures_path(statut: "archivees")
      click_on procedure.libelle
      find('#publish-procedure-link').click

      expect(find_field('procedure_path').value).to eq procedure.path
      fill_in 'procedure[lien_site_web]', with: 'http://some.website'
      click_on 'publish'

      expect(page).to have_text('Votre démarche est désormais publiée !')
    end
  end

  context 'when a procedure is closed with revision changes' do
    let!(:tdc) { { type_champ: :text, libelle: 'nouveau champ' } }
    let!(:procedure) do
      create(:procedure_with_dossiers,
        :closed,
        :with_path,
        :with_type_de_champ,
        :with_service,
        instructeurs: instructeurs,
        administrateur: administrateur)
    end

    before do
      Flipper.enable(:procedure_revisions, procedure)
      procedure.draft_revision.add_type_de_champ(tdc)
    end

    scenario 'an admin can publish it again' do
      visit admin_procedures_path(statut: "archivees")
      click_on procedure.libelle
      find('#publish-procedure-link').click

      expect(page).to have_text('Les modifications suivantes seront appliquées')
      expect(find_field('procedure_path').value).to eq procedure.path
      fill_in 'procedure[lien_site_web]', with: 'http://some.website'
      find('#publish').click

      expect(page).to have_text('Votre démarche est désormais publiée !')
    end
  end

  context 'when a procedure has dubious champs' do
    let(:dubious_champs) do
      [
        { libelle: 'NIR' },
        { libelle: 'carte bancaire' },
      ]
    end
    let(:not_dubious_champs) do
      [{ libelle: 'Prénom' }]
    end
    let!(:procedure) do
      create(:procedure,
               :with_service,
               instructeurs: instructeurs,
               administrateur: administrateur,
               types_de_champ_public: not_dubious_champs + dubious_champs)
    end

    scenario 'an admin can publish it, but a warning appears' do
      visit admin_procedures_path(statut: "brouillons")
      click_on procedure.libelle
      find('#publish-procedure-link').click

      expect(page).to have_content("Attention, certains champs ne peuvent être demandés par l’administration.")
      expect(page).to have_selector(".dubious-champs", count: dubious_champs.size)
    end
  end

  context 'when the procedure has other validation error' do
    let(:procedure) { create(:procedure, :published, :with_service, :with_type_de_champ, administrateur:) }
    let(:initiated_mail) { create(:initiated_mail, procedure:, body: "Hey!") }

    before do
      initiated_mail.body += "\n--invalid balise--"
      initiated_mail.save!(validate: false)

      procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: "Nouveau champ")
    end

    scenario 'an error message prevents the publication' do
      visit admin_procedure_path(procedure)
      expect(page).to have_content('Des problèmes empêchent la publication des modifications')
      expect(page).to have_link(href: edit_admin_procedure_mail_template_path(procedure, Mails::InitiatedMail::SLUG))
      expect(page).to have_button('Publier les modifications', disabled: true)
    end
  end
end
