# frozen_string_literal: true

# A frame cannot follow a redirect, so the server answers a bare 401. Both
# recoveries reload -- session-expiry.ts and the turbo:frame-missing handler --
# and this asserts the outcome they share: nobody is left on a dead frame.
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
