# frozen_string_literal: true

require 'system/administrateurs/procedure_spec_helper'

describe 'Closing a procedure', js: true do
  include ProcedureSpecHelper

  let(:administrateur) { administrateurs(:default_admin) }
  let!(:procedure) do
    create(:procedure_with_dossiers,
      :published,
      :with_path,
      :with_type_de_champ,
      :with_service,
      :with_zone,
      administrateur: administrateur,
      dossiers_count: 2)
  end

  let!(:other_procedure) do
    create(:procedure,
    :published,
    :with_path,
    administrateur: administrateur)
  end

  before do
    login_as administrateur.user, scope: :user
  end

  context 'when procedure is replaced in DS' do
    scenario 'the link of the new procedure is added in show page' do
      visit admin_procedure_close_path(procedure)

      expect(page).to have_current_path(admin_procedure_close_path(procedure))

      expect(page).to have_text('Clore la démarche')

      select('Je remplace ma démarche par une autre dans demarche.numerique.gouv.fr')

      select("#{other_procedure.libelle} (#{other_procedure.id})")

      accept_alert do
        within('form') { click_on 'Clore la démarche' }
      end

      procedure.reload

      expect(page).to have_current_path(admin_procedure_closing_notification_path(procedure))

      expect(page).to have_text('Votre démarche est close')
    end
  end

  context 'when procedure is not replaced in DS' do
    scenario 'the admin can notify users' do
      visit admin_procedure_close_path(procedure)

      expect(page).to have_current_path(admin_procedure_close_path(procedure))

      expect(page).to have_text('Clore la démarche')

      select('Autre')

      fill_in("Message d’information remplaçant la démarche", with: "Bonjour,\nLa démarche est maintenant sur www.autre-site.fr\nCordialement")

      accept_alert do
        within('form') { click_on 'Clore la démarche' }
      end

      procedure.reload

      expect(page).to have_current_path(admin_procedure_closing_notification_path(procedure))

      expect(page).to have_text('Votre démarche est close')

      expect(page).to have_text("Souhaitez-vous envoyer un email à l’utilisateur avec un dossier en brouillon ?")

      check("Souhaitez-vous envoyer un email à l’utilisateur avec un dossier en brouillon ?")

      expect(page).to have_text ("Contenu de l’email")

      fill_in('email_content_brouillon', with: "La démarche a fermé.")

      accept_alert do
        click_on 'Informer les usagers'
      end

      expect(page).to have_current_path(admin_procedures_path)

      visit admin_procedure_path(procedure)

      procedure.reload

      expect(page).to have_text("Un email a été envoyé pour informer les usagers le #{I18n.l(procedure.closed_at.to_date)}")
    end
  end
end
