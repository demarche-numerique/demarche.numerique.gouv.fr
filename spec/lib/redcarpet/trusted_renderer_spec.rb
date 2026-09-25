# frozen_string_literal: true

RSpec.describe Redcarpet::TrustedRenderer do
  let(:view_context) { ActionController::Base.new.view_context }
  subject(:renderer) { Redcarpet::Markdown.new(described_class.new(view_context), autolink: true) }

  context 'when rendering links' do
    it 'renders internal links without target and rel attributes' do
      markdown = "[Click here](/internal)"
      expect(renderer.render(markdown)).to include('<a href="/internal">Click here</a>')
    end

    it 'renders external links with target="_blank" and rel="noopener external"' do
      markdown = "[Visit](http://example.com)"
      expect(renderer.render(markdown)).to include('<a href="http://example.com" title="Visit — Nouvel onglet" target="_blank" rel="noopener external">Visit</a>')
    end
  end

  context 'when rendering images' do
    it 'renders an image tag with lazy loading' do
      markdown = "![A cute cat](http://example.com/cat.jpg)"
      expect(renderer.render(markdown)).to include('<img alt="A cute cat" loading="lazy" src="http://example.com/cat.jpg" />')
    end

    it 'renders additional attribute' do
      markdown = "![A cute cat { aria-hidden=\"true\" }](http://example.com/cat.jpg)"
      expect(renderer.render(markdown)).to include('<img alt="A cute cat" loading="lazy" aria-hidden="true" src="http://example.com/cat.jpg" />')
    end
  end

  context 'when autolinking' do
    it 'autolinks URLs' do
      markdown = "Visit http://example.com"
      expect(renderer.render(markdown)).to include('Visit <a href="http://example.com" title="http://example.com — Nouvel onglet" target="_blank" rel="noopener external">http://example.com</a>')
    end

    it 'autolinks email addresses with mailto' do
      markdown = "Email user@example.com"
      expect(renderer.render(markdown)).to include('<a href="mailto:user@example.com">user@example.com</a>')
    end
  end

  context 'with block_quote DSFR alert' do
    it 'renders [!INFO] blocks as DSFR info alerts' do
      markdown = "> [!INFO]\n> This is an information alert with *emphasis*."
      expected_html = <<~HTML
        <div class='fr-alert fr-alert--info fr-my-3w'>
        <h2 class="fr-alert__title">Information : </h2>
        <p>This is an information alert with <em>emphasis</em>.</p>
        </div>
      HTML
      expect(renderer.render(markdown).delete("\n")).to include(expected_html.delete("\n"))
    end

    it 'renders [!WARNING] blocks as DSFR warning alerts' do
      markdown = "> [!WARNING]\n> This is a warning alert."
      expected_html = <<~HTML
        <div class='fr-alert fr-alert--warning fr-my-3w'>
        <h2 class="fr-alert__title">Attention : </h2>
        <p>This is a warning alert.</p>
        </div>
      HTML
      expect(renderer.render(markdown).delete("\n")).to include(expected_html.delete("\n"))
    end
  end
end
