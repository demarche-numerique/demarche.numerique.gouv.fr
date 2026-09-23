# frozen_string_literal: true

RSpec.describe SettingsTileComponent, type: :component do
  subject(:rendered) do
    render_inline(described_class.new(url: '/somewhere', badge:, **options)) do |tile|
      tile.with_title { 'Mon titre' }
      tile.with_action { action } if action
    end
  end

  let(:badge) { { label: 'Validé', variant: :success } }
  let(:options) { {} }
  let(:action) { nil }

  it 'renders a tile linking to the url' do
    is_expected.to have_link(href: '/somewhere', class: 'fr-tile')
    is_expected.to have_css('p.fr-badge.fr-badge--success', text: 'Validé')
    is_expected.to have_css('h3.fr-h6', text: 'Mon titre')
    is_expected.to have_css('p.fr-btn', text: 'Modifier')
    is_expected.to have_no_css('.fr-tag')
    is_expected.to have_no_css('.fr-tile-subtitle')
  end

  context 'with a badge without variant nor icon' do
    let(:badge) { { label: 'Par défaut', icon: false } }

    it { is_expected.to have_css('p.fr-badge.fr-badge--no-icon:not([class*="fr-badge--success"])', text: 'Par défaut') }
  end

  context 'with an unknown badge variant' do
    let(:badge) { { label: 'Oups', variant: :danger } }

    it { expect { rendered }.to raise_error(ArgumentError) }
  end

  context 'with a counter' do
    let(:options) { { counter: 0 } }

    it 'shows it and drops the spacing that stands in for it' do
      is_expected.to have_css('p.fr-tag', text: '0')
      is_expected.to have_css('h3.fr-h6:not(.fr-mt-10v)')
    end
  end

  context 'without a counter' do
    it { is_expected.to have_css('h3.fr-h6.fr-mt-10v') }
  end

  context 'with a subtitle, a heading level and link attributes' do
    let(:options) { { subtitle: 'Sous-titre', heading_level: :h4, link_attributes: { id: 'my-tile', title: nil } } }

    it do
      is_expected.to have_css('p.fr-tile-subtitle', text: 'Sous-titre')
      is_expected.to have_css('h4', text: 'Mon titre')
      is_expected.to have_css('a#my-tile:not([title])')
    end
  end

  context 'with a custom action' do
    let(:action) { 'Configurer' }

    it { is_expected.to have_css('p.fr-btn', text: 'Configurer') }
  end
end
