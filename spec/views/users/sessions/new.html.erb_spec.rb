# frozen_string_literal: true

describe 'users/sessions/new', type: :view do
  before(:each) do
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:resource).and_return(User.new)
    allow(view).to receive(:pro_connect_only_login?).and_return(false)
  end

  before do
    assign(:user, User.new)
    params[:with_proconnect] = with_proconnect if with_proconnect
  end

  let(:with_proconnect) { nil }

  context 'when FranceConnect and ProConnect are enabled' do
    before do
      allow(FranceConnectService).to receive(:enabled?).and_return(true)
      allow(ProConnectService).to receive(:enabled?).and_return(true)
      render
    end

    it 'renders form fields' do
      expect(rendered).to have_field('Adresse électronique')
      expect(rendered).to have_field('Mot de passe')
      expect(rendered).to have_button('Se connecter')
    end

    it 'renders FranceConnect login button' do
      expect(rendered).to have_css('.france-connect-login')
    end

    it 'does not render ProConnect login button by default' do
      expect(rendered).not_to have_css('.pro-connect-login')
    end

    context 'when with_proconnect query param is present' do
      let(:with_proconnect) { 'true' }

      it 'renders ProConnect login button' do
        expect(rendered).to have_css('.pro-connect-login')
      end
    end
  end

  context 'when the browser is marked as an administrateur device but the visitor was invited' do
    before do
      allow(view).to receive(:pro_connect_only_login?).and_return(true)
      params[:context] = 'invite'
      render
    end

    it 'renders the full form' do
      expect(rendered).to have_field('Mot de passe')
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
