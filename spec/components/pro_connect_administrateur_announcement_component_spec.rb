# frozen_string_literal: true

RSpec.describe ProConnectAdministrateurAnnouncementComponent, type: :component do
  subject { render_inline(described_class.new) }

  it 'announces the ProConnect-only administrateur login' do
    expect(subject).to have_css('.fr-notice__title', text: 'Évolution du mode de connexion ADMINISTRATEUR')
    expect(subject).to have_link('ProConnect', href: 'https://www.proconnect.gouv.fr/')
  end
end
