# frozen_string_literal: true

describe 'users/registrations/new', type: :view do
  before(:each) do
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:resource).and_return(User.new)
  end

  before do
    assign(:user, User.new)
  end

  context 'when ProConnect is enabled' do
    before do
      allow(ProConnectService).to receive(:enabled?).and_return(true)
      render
    end

    it 'renders ProConnect login button' do
      expect(rendered).to have_css('.pro-connect-login')
    end
  end

  context 'when ProConnect is disabled' do
    before do
      allow(ProConnectService).to receive(:enabled?).and_return(false)
      render
    end

    it 'does not render ProConnect login button' do
      expect(rendered).not_to have_css('.pro-connect-login')
    end
  end
end
