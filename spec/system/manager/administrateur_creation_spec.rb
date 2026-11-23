# frozen_string_literal: true

describe 'Manager: création de comptes administrateurs', js: true do
  include OtpHelpers

  let(:requester) { create(:super_admin, :with_otp) }
  let(:validator) { create(:super_admin, :with_otp) }
  let(:emails) { Array.new(11) { "agent.#{it}@numerique.gouv.fr" } }

  def paste(text)
    find_field('Adresses électroniques').set(text)
    page.execute_script(<<~JS)
      document.getElementById('emails').dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertFromPaste' }))
    JS
  end

  scenario 'un super admin demande 11 comptes, un autre valide la demande' do
    login_as(requester, scope: :super_admin)
    visit new_manager_administrateur_path

    paste("Agent 0 <Agent.0@numerique.gouv.fr>; #{emails.join(', ')}")
    expect(find_field('Adresses électroniques').value).to eq(emails.join("\n"))
    expect(page).to have_text('numerique.gouv.fr · 11')
    expect(page).to have_text('un lien à transmettre à un autre super admin')

    fill_in 'Code OTP', with: current_otp_for(requester)
    click_on 'Demander la validation (création de 11 comptes)'

    expect(page).to have_text('Lien à transmettre à un autre super admin')
    creation_request = AdministrateurCreationRequest.last
    expect(find_field('Lien de validation').value).to end_with(manager_administrateur_creation_request_path(creation_request))

    logout(:super_admin)
    login_as(validator, scope: :super_admin)
    visit manager_administrateur_creation_request_path(creation_request)

    expect(page).to have_text("#{requester.email} demande la création de 11 comptes administrateurs")
    fill_in 'Code OTP', with: current_otp_for(validator)
    click_on 'Valider la création de 11 comptes administrateurs'

    expect(page).to have_text('Demande validée')
    perform_enqueued_jobs(only: AdministrateurCreationRequestJob)
    expect(Administrateur.joins(:user).where(users: { email: emails }).count).to eq(11)
  end

  scenario 'au-delà de 100 adresses, le bouton est désactivé' do
    login_as(requester, scope: :super_admin)
    visit new_manager_administrateur_path

    paste(Array.new(101) { "agent.#{it}@numerique.gouv.fr" }.join(' '))

    expect(page).to have_text('Vous ne pouvez pas créer plus de 100 comptes par demande.')
    expect(page).to have_button('Demander la validation (création de 101 comptes)', disabled: true)
  end
end
