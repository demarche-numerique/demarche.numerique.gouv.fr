# frozen_string_literal: true

describe SimpleFormatComponent, type: :component do
  let(:allow_a) { false }
  let(:allow_autolink) { false }
  before { render_inline(described_class.new(text, allow_a: allow_a, allow_autolink: allow_autolink)) }

  context 'one line' do
    let(:text) do
      "1er paragraphe"
    end
    it { expect(page).to have_selector("p", count: 1, text: text) }
  end

  context 'one with leading spaces' do
    let(:text) do
      <<-TEXT
      1er paragraphe
TEXT
    end
    it { expect(page).to have_selector("p", count: 1, text: text.strip) }
  end

  context 'two lines' do
    let(:text) do
      <<~TEXT
        1er paragraphe
        2eme paragraphe
      TEXT
    end

    it do
      expect(page).to have_selector("p", count: 2)
      text.split("\n").map(&:strip).map { expect(page).to have_text(_1) }
    end
  end

  context 'unordered list items' do
    let(:text) do
      <<~TEXT
        - 1er paragraphe
        - paragraphe
      TEXT
    end

    it do
      expect(page).to have_selector("ul", count: 1)
      expect(page).to have_selector("li", count: 2)
    end
  end

  context 'ordered list items' do
    let(:text) do
      <<~TEXT
        1. 1er paragraphe
        2. paragraphe
        4. 4eme paragraphe
      TEXT
    end

    it do
      expect(page).to have_selector("ol", count: 1)
      expect(page).to have_selector("li", count: 3)
      expect(page.native.inner_html).to match('value="1"')
      expect(page.native.inner_html).to match('value="4"')
    end
  end

  context 'multi line lists' do
    let(:text) do
      <<~TEXT
        Lorsque nous souhaitons envoyer ce message :

        1. Premier point de la recette
        Commentaire 1
        2. Deuxième point de la recette
          Commentaire 2

        4. Troisième point de la recette
        Commentaire 3

        trois nouveaux paragraphes
        sur plusieures
        lignes

        - 1er point de la recette
        * 2eme point de la recette
        avec des détailles
        + 3eme point de la recette
        beaucoup
        de détails

        conclusion
      TEXT
    end

    it do
      expect(page).to have_selector("ol", count: 1)
      expect(page).to have_selector("ul", count: 1)
      expect(page).to have_selector("li", count: 6)
      expect(page).to have_selector("p", count: 5)
    end
  end

  context 'strong' do
    let(:text) do
      <<~TEXT
        1er paragraphe **fort** un_mot_pas_italic
      TEXT
    end

    it do
      expect(page).to have_selector("strong", count: 1)
      expect(page).not_to have_selector("em")
    end
  end

  context 'auto-link' do
    let(:text) do
      <<~TEXT
        bonjour https://demarche.numerique.gouv.fr
        nohttp www.ds.io
        ecrivez à ds@rspec.io
        <a href="https://demarche.numerique.gouv.fr">lien html</a>
        [lien markdown](https://github.com)
      TEXT
    end

    context 'enabled with html links' do
      let(:allow_a) { true }
      it { expect(page).to have_selector("a") }
      it "inject expected attributes" do
        link = page.find_link("https://demarche.numerique.gouv.fr").native
        expect(link[:rel]).to eq("noopener external")
        expect(link[:title]).to eq("Nouvel onglet")
      end

      it "convert email autolinks" do
        link = page.find_link("ds@rspec.io").native
        expect(link[:href]).to eq("mailto:ds@rspec.io")
        expect(link[:rel]).to be_nil
      end

      context "followed by a multibyte character (no-break space before a colon, accented letter)" do
        # On macOS Redcarpet swallows the lead byte of the next character into the link
        let(:text) { "Contact : ds@rspec.io\u00A0: écrire à ds@rspec.frécrivez, voir https://ds.io/aide\u00A0!" }

        it "links the address alone and keeps the following character" do
          expect(page.find_link("ds@rspec.io").native[:href]).to eq("mailto:ds@rspec.io")
          expect(page.find_link("ds@rspec.fr").native[:href]).to eq("mailto:ds@rspec.fr")
          # Redcarpet's URL scanner stops on ASCII whitespace only, so with glibc
          # the no-break space stays inside the link: check the link, not its href
          expect(page).to have_link("https://ds.io/aide")
          expect(page.text).to include("ds@rspec.io\u00A0: écrire à ds@rspec.frécrivez, voir https://ds.io/aide\u00A0!")
        end
      end

      it "convert www only" do
        link = page.find_link("www.ds.io").native
        expect(link[:href]).to eq("http://www.ds.io")
        expect(link[:rel]).to eq("noopener external")
        expect(link[:title]).to eq("Nouvel onglet")
      end

      it "render html link" do
        link = page.find_link("lien html").native
        expect(link[:href]).to eq("https://demarche.numerique.gouv.fr")
      end

      it "convert markdown link" do
        link = page.find_link("lien markdown").native
        expect(link[:href]).to eq("https://github.com")
        expect(link[:rel]).to eq("noopener external")
        expect(link[:title]).to eq("Nouvel onglet")
      end
    end

    context 'enabled only without html links' do
      let(:allow_autolink) { true }

      it "convert only visible http link, not html links" do
        expect(page).to have_link("https://demarche.numerique.gouv.fr")
        expect(page).to have_selector("a", count: 1)
      end

      it "inject expected attributes" do
        link = page.find_link("https://demarche.numerique.gouv.fr").native
        expect(link[:rel]).to eq("noopener external")
        expect(link[:title]).to include("Nouvel onglet")
      end

      context 'url ending the paragraph' do
        let(:text) { "bonjour https://demarche.numerique.gouv.fr" }

        it "does not include the closing p" do
          link = page.find_link("https://demarche.numerique.gouv.fr").native
          expect(link[:href]).to eq("https://demarche.numerique.gouv.fr")
          expect(link.text).to eq("https://demarche.numerique.gouv.fr")
        end
      end
    end

    context 'completely disabled' do
      it { expect(page).not_to have_selector("a") }
    end
  end

  context 'emphasis not in urls' do
    let(:text) do
      <<~TEXT
        A _string emphased_ but https://example.fr/path_preserves_underscore
        email: here_is_my@email.com
      TEXT
    end

    context "without autolink" do
      let(:allow_a) { false }
      it do
        expect(page).to have_selector("em", count: 1, text: "string emphased")
        expect(page).to have_text("https://example.fr/path_preserves_underscore")
        expect(page).to have_text("email: here_is_my@email.com")
      end
    end

    context "with autolink" do
      let(:allow_a) { true }
      it {
        expect(page).to have_link("https://example.fr/path_preserves_underscore")

        # NOTE: As of Redcarpet 3.6.0, autolinking email containing _ is broken https://github.com/vmg/redcarpet/issues/402
        # but we still want the email to be displayed
        expect(page).to have_text("here_is_my@email.com")
      }
    end
  end

  context 'urls with query parameters' do
    let(:text) do
      "Visitez https://www.google.com/search?variable=value&q=ecologie pour plus d'infos"
    end

    context 'with autolink only (instructeur messages)' do
      let(:allow_autolink) { true }
      let(:allow_a) { false }

      it "displays URL correctly without double-encoding ampersands" do
        expect(page).to have_link("https://www.google.com/search?variable=value&q=ecologie", href: "https://www.google.com/search?variable=value&q=ecologie")
      end

      it "does not contain double-encoded ampersands in HTML" do
        expect(page.native.inner_html).not_to include("&amp;amp;")
        expect(page.native.inner_html).to include("&amp;")
      end
    end

    context 'with full autolink (allow_a: true)' do
      let(:allow_a) { true }

      it "displays URL correctly" do
        expect(page).to have_link("https://www.google.com/search?variable=value&q=ecologie", href: "https://www.google.com/search?variable=value&q=ecologie")
      end
    end
  end

  context 'XSS protection in autolink' do
    let(:text) { 'Visitez http://example.com<script>alert("xss")</script> pour plus d\'infos' }
    let(:allow_autolink) { true }

    it "does not render script tags in autolinked URLs" do
      expect(page.native.inner_html).not_to include('<script>')
      expect(page).to have_text('http://example.comalert(&quot;xss&quot;)')
    end
  end
end
