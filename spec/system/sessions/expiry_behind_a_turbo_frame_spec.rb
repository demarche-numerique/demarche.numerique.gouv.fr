# frozen_string_literal: true

# A session can die between two Turbo requests. The frame follows the redirect
# to the sign in page, which carries turbo-visit-control: Turbo leaves the frame
# and loads it as a whole page. What that page says is covered by
# spec/requests/session_failure_app_spec.rb.
describe 'a session that dies behind a turbo frame', js: true do
  # The seeded procedure is published and already assigned to this instructeur,
  # so the dossier list has a frame to load.
  let(:instructeur) { instructeurs.default }
  let!(:procedure) { procedures.individual }

  before do
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedures_path
  end

  scenario 'leaves the frame and sends the browser to the sign in page' do
    instructeur.user.revoke_sessions!(reason: :logout_all)

    click_on 'Synthèse des dossiers'

    expect(page).to have_current_path(new_user_session_path)
  end
end
