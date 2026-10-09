# frozen_string_literal: true

describe 'Manager: ajout d’un administrateur sur une démarche', js: true do
  let(:super_admin) { create(:super_admin) }
  let(:procedure) { procedures.individual }

  before { login_as(super_admin, scope: :super_admin) }

  scenario 'un super admin copie le lien de confirmation' do
    visit new_manager_procedure_confirmation_url_path(procedure, email: administrateurs.blank.email)

    click_on 'Copier le lien'

    expect(page).to have_text('Le lien est copié')
    copied = find('[data-controller="clipboard"]')['data-clipboard-text-value']
    expect(copied).to include("#{new_manager_procedure_administrateur_confirmation_path(procedure)}?q=")
  end
end
