# frozen_string_literal: true

RSpec.describe Dossiers::JdmaButtonComponent, type: :component do
  let(:procedure) { build(:procedure, monavis_embed:) }

  context 'without a JDMA embed' do
    let(:monavis_embed) { nil }

    it 'renders nothing' do
      render_inline(described_class.new(procedure:))
      expect(page).not_to have_css('.fr-callout')
    end
  end

  context 'with a valid JDMA embed' do
    let(:monavis_embed) do
      '<a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?nd_source=button&key=abc"><img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu-clair.svg" alt="x" /></a>'
    end

    before { render_inline(described_class.new(procedure:)) }

    it 'links to the feedback URL with source=site, in a new tab' do
      expect(page).to have_link(href: "https://jedonnemonavis.numerique.gouv.fr/Demarches/123?nd_source=site&key=abc")
      expect(page).to have_css("a[target='_blank'][rel='noopener external']")
    end

    it 'renders both light and dark button images' do
      expect(page).to have_css('img.hidden-on-dark-theme')
      expect(page).to have_css('img.hidden-on-light-theme')
    end
  end
end
