# frozen_string_literal: true

describe 'Manager: ajout d’un administrateur sur une démarche', js: true do
  let(:super_admin) { create(:super_admin) }
  let(:procedure) { procedures.individual }

  before do
    login_as(super_admin, scope: :super_admin)

    Capybara.current_session.driver.with_playwright_page do |page|
      page.context.grant_permissions(['clipboard-read', 'clipboard-write'])
    end
  end

  scenario 'un super admin copie le lien de confirmation' do
    visit new_manager_procedure_confirmation_url_path(procedure, email: administrateurs.blank.email)

    click_on 'Copier le lien'

    copied = page.document.synchronize do
      page.evaluate_async_script('navigator.clipboard.readText().then(arguments[0])').presence ||
        raise(Capybara::ExpectationNotMet, 'clipboard is empty')
    end
    expect(copied).to include("#{new_manager_procedure_administrateur_confirmation_path(procedure)}?q=")
  end
end
