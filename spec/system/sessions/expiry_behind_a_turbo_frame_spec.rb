# frozen_string_literal: true

# A session can die between two Turbo requests. The server answers those with a
# bare 401 rather than a redirect, because a sign in page rendered inside a
# frame would land in a corner of the layout.
#
# Two mechanisms carry the browser out of that frame: `session-expiry.ts`, which
# follows the sign in path the 401 carries, and the `turbo:frame-missing`
# handler on the frame, which reloads. This asserts the outcome they share --
# nobody is left on a dead frame -- and stays true if either one goes.
#
# What the sign in page then says is covered by
# spec/requests/session_failure_app_spec.rb.
describe 'a session that dies behind a turbo frame', js: true do
  # The seeded procedure is published and already assigned to this instructeur,
  # so the dossier list has a frame to load.
  let(:instructeur) { instructeurs.default }
  let!(:procedure) { procedures.individual }

  before do
    Flipper.enable_actor(:session_registry, instructeur.user)
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedures_path
  end

  scenario 'leaves the frame and sends the browser to the sign in page' do
    instructeur.user.revoke_sessions!(reason: :logout_all)

    click_on 'Synthèse des dossiers'

    expect(page).to have_current_path(new_user_session_path)
  end
end
