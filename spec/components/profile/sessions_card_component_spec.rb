# frozen_string_literal: true

describe Profile::SessionsCardComponent, type: :component do
  let(:user) { create(:user) }
  let(:chrome) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36' }

  before do
    Flipper.enable_actor(:session_registry, user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  subject { render_inline(described_class.new) && page }

  context 'with no session in the registry' do
    # An empty table would read as "you are signed in nowhere", which is false:
    # the person is reading the page.
    it 'renders nothing at all' do
      expect(subject.native.text).to be_blank
    end
  end

  context 'with two sessions' do
    let!(:current_session) { user.open_user_session!(chrome) }
    let!(:other_session) { user.open_user_session!('Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0') }

    before { allow(Current).to receive(:user_session_id).and_return(current_session.id) }

    it 'labels each device from its user agent' do
      expect(subject).to have_text('Chrome sur macOS')
      expect(subject).to have_text('Firefox sur Linux')
    end

    it 'marks which one is being used right now, once' do
      expect(subject.all('.fr-badge', text: 'Session actuelle').count).to eq(1)
    end

    it 'offers to sign the other devices out, named in the accessible label' do
      expect(subject).to have_selector("[aria-label='Déconnecter l’appareil Firefox sur Linux']")
    end

    # Signing out is what the header is for. A "Déconnecter" sitting next to
    # "Session actuelle" reads as closing somebody else's device.
    it 'offers nothing on the row being read from' do
      expect(subject).not_to have_selector("[aria-label='Déconnecter l’appareil Chrome sur macOS']")
    end

    it 'shows when each session was opened, in the format the rest of the app uses' do
      expect(subject).to have_text(I18n.l(other_session.created_at, format: :long_with_time))
    end

    it 'does not show an expiry column' do
      expect(subject).not_to have_text('Expiration')
    end

    it 'offers to sign every device out, this one included' do
      expect(subject).to have_button('Déconnecter tous les appareils')
    end

    it 'never prints the raw user agent, only the label' do
      expect(subject.native.to_s).not_to include('AppleWebKit')
    end
  end

  context 'with a single session' do
    let!(:only_session) { user.open_user_session!(chrome) }

    # Nothing to sign out but the one you are reading this on.
    it 'does not offer to sign the others out' do
      expect(subject).not_to have_button('Déconnecter tous les autres appareils')
    end
  end

  # Rows outlive a rollback of the flag, and nothing enforces them while it is
  # off: showing the list would offer buttons that report closing a device
  # which stays signed in.
  context 'with the registry closed for the account' do
    let!(:session) { user.open_user_session!(chrome) }

    before { Flipper.disable_actor(:session_registry, user) }

    it 'renders nothing at all' do
      expect(subject.native.text).to be_blank
    end
  end

  context 'with a revoked session' do
    let!(:revoked) { user.open_user_session!(chrome) }
    let!(:live) { user.open_user_session!('Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0') }

    before { user.user_sessions.where(id: revoked.id).revoke_all!(:logout_device) }

    it 'lists only what is still usable' do
      expect(subject).to have_text('Firefox sur Linux')
      expect(subject).not_to have_text('Chrome sur macOS')
    end
  end
end
