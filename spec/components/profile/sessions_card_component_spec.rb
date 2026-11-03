# frozen_string_literal: true

describe Profile::SessionsCardComponent, type: :component do
  let(:user) { create(:user) }
  let(:chrome) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36' }
  let(:current_user_session) { defined?(current_session) ? current_session : nil }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  subject { render_inline(described_class.new(current_user_session:)) && page }

  context 'with no session in the registry' do
    it 'renders nothing at all' do
      expect(subject.native.text).to be_blank
    end
  end

  context 'with two sessions' do
    let!(:current_session) { user.open_user_session!(chrome) }
    let!(:other_session) { user.open_user_session!('Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0') }

    it 'labels each device from its user agent' do
      expect(subject).to have_text('Chrome sur macOS')
      expect(subject).to have_text('Firefox sur Linux')
    end

    it 'marks which one is being used right now, once' do
      expect(subject.all('.fr-badge', text: 'Session actuelle').count).to eq(1)
    end

    it 'offers to sign the other devices out, named in the accessible label' do
      opened_at = I18n.l(other_session.created_at, format: :long_with_time)

      expect(subject)
        .to have_selector("[aria-label='Déconnecter l’appareil Firefox sur Linux, session ouverte le #{opened_at}']")
    end

    it 'offers nothing on the row being read from' do
      expect(subject).not_to have_selector("[aria-label^='Déconnecter l’appareil Chrome sur macOS']")
    end

    it 'tells apart two devices that share a label' do
      user
        .open_user_session!('Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0')
        .update_column(:created_at, 2.hours.ago)

      labels = subject.all('button[aria-label]').map { it['aria-label'] }

      expect(labels.count).to eq(2)
      expect(labels.uniq.count).to eq(2)
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

    it 'does not offer to sign the others out' do
      expect(subject).not_to have_button('Déconnecter tous les autres appareils')
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
