# frozen_string_literal: true

RSpec.describe ProConnectAdministrateurAnnouncementComponent, type: :component do
  subject { render_inline(described_class.new) }

  it 'renders nothing while the announcement is off' do
    expect(subject.to_html.strip).to be_empty
  end

  context 'when the announcement is on' do
    before { Flipper.enable(:pro_connect_administrateur_announcement) }

    it 'announces the ProConnect-only administrateur login' do
      expect(subject).to have_css('.fr-notice__title', text: 'Évolution du mode de connexion administrateur')
      expect(subject).to have_link('ProConnect', href: 'https://www.proconnect.gouv.fr/')
    end
  end
end
