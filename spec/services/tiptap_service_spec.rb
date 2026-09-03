# frozen_string_literal: true

RSpec.describe TiptapService do
  let(:json) do
    {
      type: 'doc',
      content: [
        {
          type: 'header',
          content: [
            {
              type: 'headerColumn',
              content: [{ type: 'text', text: 'Left' }],
            },
            {
              type: 'headerColumn',
              content: [{ type: 'text', text: 'Right' }],
            },
          ],
        },
        {
          type: 'title',
          content: [{ type: 'text', text: 'Title' }],
        },
        {
          type: 'title', # remained empty in editor
        },
        {
          type: 'heading',
          attrs: { level: 2, textAlign: 'center' },
          content: [{ type: 'text', text: 'Heading 2' }],
        },
        {
          type: 'heading',
          attrs: { level: 3, textAlign: 'center' },
          content: [{ type: 'text', text: 'Heading 3' }],
        },
        {
          type: 'heading',
          attrs: { level: 3 }, # remained empty in editor
        },
        {
          type: 'paragraph',
          attrs: { textAlign: 'right' },
          content: [{ type: 'text', text: 'First paragraph' }],
        },
        {
          type: 'paragraph',
          content: [
            {
              type: 'text',
              text: 'Bonjour ',
              marks: [{ type: 'italic' }],
            },
            {
              type: 'mention',
              attrs: { id: 'name', label: 'Nom' },
              marks: [{ type: 'bold' }, { type: 'underline' }],
            },
            {
              type: 'text',
              text: ' ',
            },
            {
              type: 'text',
              text: '!',
              marks: [{ type: 'highlight' }],
            },
          ],
        },
        {
          type: 'paragraph',
          # no content, empty line
        },
        {
          type: 'bulletList',
          content: [
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 1',
                    },
                  ],
                },
              ],
            },
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 2',
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'orderedList',
          content: [
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 1',
                    },
                  ],
                },
              ],
            },
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 2',
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'paragraph',
          content: [
            {
              type: 'text',
              text: 'Langages de prédilection:',
            },
            {
              type: 'mention',
              attrs: { id: 'languages', label: 'Langages' },
            },
          ],
        },
        {
          type: 'footer',
          content: [{ type: 'text', text: 'Footer' }],
        },
      ],
    }
  end

  describe '.to_html' do
    let(:substitutions) { { 'name' => 'Paul', 'languages' => ChampPresentations::MultipleDropDownListPresentation.new(['ruby', 'rust']) } }
    let(:html) do
      [
        '<header><div>Left</div><div>Right</div></header>',
        '<h1>Title</h1>',
        '<h2 class="body-start" style="text-align: center">Heading 2</h2>',
        '<h3 style="text-align: center">Heading 3</h3>',
        '<p style="text-align: right">First paragraph</p>',
        '<p><em>Bonjour </em><u><strong>Paul</strong></u> <mark>!</mark></p>',
        '<ul><li>Item 1</li><li>Item 2</li></ul>',
        '<ol><li>Item 1</li><li>Item 2</li></ol>',
        '<p>Langages de prédilection:</p><ul><li>ruby</li><li>rust</li></ul>',
        '<footer>Footer</footer>',
      ].join
    end

    it 'returns html' do
      expect(described_class.new.to_html(json, substitutions)).to eq(html)
    end

    context 'body start on paragraph' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'title',
              content: [{ type: 'text', text: 'The Title' }],
            },
            {
              type: 'paragraph',
              content: [{ type: 'text', text: 'First paragraph' }],
            },
          ],
        }
      end

      it 'defines stat body on first paragraph' do
        expect(described_class.new.to_html(json, substitutions)).to eq("<h1>The Title</h1><p class=\"body-start\">First paragraph</p>")
      end
    end

    context 'hard break' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'paragraph',
              content: [
                {
                  type: 'text',
                  text: 'Première ligne',
                },
                {
                  type: 'hardBreak',
                },
                {
                  type: 'text',
                  text: 'Seconde ligne',
                },
              ],
            },
          ],
        }
      end

      it 'renders a line break' do
        expect(described_class.new.to_html(json, {})).to eq(
          '<p class="body-start">Première ligne<br>Seconde ligne</p>'
        )
      end

      it 'renders the hard_break given at initialization (blank line for attestations)' do
        expect(described_class.new(hard_break: '<br><br>').to_html(json, {})).to eq(
          '<p class="body-start">Première ligne<br><br>Seconde ligne</p>'
        )
      end
    end

    context 'link mark' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'paragraph',
              content: [
                {
                  type: 'text',
                  text: 'Cliquez ',
                },
                {
                  type: 'text',
                  text: 'ici',
                  marks: [{ type: 'link', attrs: { href: 'https://example.com' } }],
                },
                {
                  type: 'text',
                  text: ' pour continuer.',
                },
              ],
            },
          ],
        }
      end

      it 'renders link with security attributes' do
        expect(described_class.new.to_html(json, {})).to eq(
          '<p class="body-start">Cliquez <a href="https://example.com" target="_blank" rel="noopener noreferrer">ici</a> pour continuer.</p>'
        )
      end

      context 'with XSS attempt in href' do
        let(:json) do
          {
            type: 'doc',
            content: [
              {
                type: 'paragraph',
                content: [
                  {
                    type: 'text',
                    text: 'link',
                    marks: [{ type: 'link', attrs: { href: '"><script>alert(1)</script>' } }],
                  },
                ],
              },
            ],
          }
        end

        it 'escapes malicious href' do
          expect(described_class.new.to_html(json, {})).to include('&quot;&gt;&lt;script&gt;')
        end
      end
    end

    context 'page break node' do
      let(:json) do
        {
          type: 'doc',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'Avant' }] },
            { type: 'pageBreak' },
            { type: 'paragraph', content: [{ type: 'text', text: 'Après' }] },
          ],
        }
      end

      it 'renders a page-break div without consuming the body-start mark' do
        expect(described_class.new.to_html(json)).to eq(
          '<p class="body-start">Avant</p><div class="page-break"></div><p>Après</p>'
        )
      end

      it 'does not render a page-break div when it is the first node' do
        json = {
          type: 'doc',
          content: [
            { type: 'pageBreak' },
            { type: 'paragraph', content: [{ type: 'text', text: 'Premier paragraphe' }] },
          ],
        }
        expect(described_class.new.to_html(json)).to eq(
          '<p class="body-start">Premier paragraphe</p>'
        )
      end
    end

    context 'ordered list with custom classes' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'orderedList',
              attrs: { class: "my-class" },
              content: [
                {
                  type: 'listItem',
                  content: [
                    {
                      type: 'paragraph',
                      content: [
                        {
                          type: 'text',
                          text: 'Item 1',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        }
      end

      it "set class attribute" do
        expect(described_class.new.to_html(json, substitutions)).to eq('<ol class="my-class body-start"><li>Item 1</li></ol>')
      end
    end
    context 'block presentation (list rendered for a champ tag)' do
      let(:presentation) { ChampPresentations::MultipleDropDownListPresentation.new(['ruby', 'rust']) }
      let(:substitutions) { { 'languages' => presentation } }
      let(:mention) { { type: 'mention', attrs: { id: 'languages', label: 'Langages' } } }
      let(:list) { '<ul><li>ruby</li><li>rust</li></ul>' }

      def doc(*content) = { type: 'doc', content: }
      def text(text) = { type: 'text', text: }

      it 'splits the paragraph around the list and keeps the paragraph attributes on both halves' do
        json = doc({ type: 'paragraph', attrs: { textAlign: 'center' }, content: [text('Avant '), mention, text(' après')] })

        expect(described_class.new.to_html(json, substitutions)).to eq(
          "<p class=\"body-start\" style=\"text-align: center\">Avant </p>#{list}<p style=\"text-align: center\"> après</p>"
        )
      end

      it 'does not emit empty paragraphs around a mention at the start or the end' do
        json = doc({ type: 'paragraph', content: [text('Intro')] }, { type: 'paragraph', content: [mention] })

        expect(described_class.new.to_html(json, substitutions)).to eq("<p class=\"body-start\">Intro</p>#{list}")
      end

      it 'moves the body-start mark to the list when the body starts with a mention' do
        json = doc({ type: 'paragraph', content: [mention, text(' après')] })

        expect(described_class.new.to_html(json, substitutions)).to eq(
          "<ul class=\"body-start\"><li>ruby</li><li>rust</li></ul><p> après</p>"
        )
      end

      it 'keeps the presentation class when adding the body-start mark' do
        repetition = ChampPresentations::RepetitionPresentation.new('Rows', [])
        json = doc({ type: 'paragraph', content: [{ type: 'mention', attrs: { id: 'rows', label: 'Rows' } }] })

        expect(described_class.new.to_html(json, { 'rows' => repetition })).to eq('<ol class="tdc-repetition body-start"></ol>')
      end

      it 'nests the list inside a list item' do
        json = doc({ type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [text('Item '), mention] }] }] })

        expect(described_class.new.to_html(json, substitutions)).to eq("<ul class=\"body-start\"><li>Item #{list}</li></ul>")
      end

      it 'falls back to the text form inside a heading' do
        json = doc({ type: 'heading', attrs: { level: 2 }, content: [text('Titre '), mention] })

        expect(described_class.new.to_html(json, substitutions)).to eq('<h2 class="body-start">Titre ruby, rust</h2>')
      end

      it 'falls back to the escaped text form inside the title' do
        json = doc({ type: 'title', content: [mention] })
        substitutions = { 'languages' => ChampPresentations::MultipleDropDownListPresentation.new(['<b>']) }

        expect(described_class.new.to_html(json, substitutions)).to eq('<h1>&lt;b&gt;</h1>')
      end

      it 'stringifies non-string substitutions in the inline runs' do
        json = doc({ type: 'paragraph', content: [text('N° '), { type: 'mention', attrs: { id: 'number', label: 'N°' } }, mention] })

        expect(described_class.new.to_html(json, substitutions.merge('number' => 42))).to eq("<p class=\"body-start\">N° 42</p>#{list}")
      end

      it 'ignores marks on the mention' do
        json = doc({ type: 'paragraph', content: [text('Avant '), mention.merge(marks: [{ type: 'bold' }])] })

        expect(described_class.new.to_html(json, substitutions)).to eq("<p class=\"body-start\">Avant </p>#{list}")
      end

      it 'keeps an inline presentation inside the paragraph, with the mention marks and the hard break' do
        motivation = { type: 'mention', attrs: { id: 'motivation', label: 'Motivation' }, marks: [{ type: 'italic' }] }
        json = doc({ type: 'paragraph', content: [text('Motivation : '), motivation, text('.')] })
        substitutions = { 'motivation' => ChampPresentations::MultilineTextPresentation.new("<b>ok</b>\nsuite") }

        expect(described_class.new(hard_break: '<br><br>').to_html(json, substitutions)).to eq(
          '<p class="body-start">Motivation : <em>&lt;b&gt;ok&lt;/b&gt;</em><br><br><em>suite</em>.</p>'
        )
      end
    end
  end

  describe '.resolve' do
    let(:presentation) { ChampPresentations::MultipleDropDownListPresentation.new(['ruby', 'rust']) }
    let(:substitutions) { { 'name' => 'Paul', 'languages' => presentation } }
    let(:mention) { { type: 'mention', attrs: { id: 'languages', label: 'Langages' } } }
    let(:name) { { type: 'mention', attrs: { id: 'name', label: 'Nom' }, marks: [{ type: 'bold' }] } }

    def doc(*content) = { type: 'doc', content: }
    def text(text, **rest) = { type: 'text', text:, **rest }

    it 'returns nil for a nil document' do
      expect(described_class.resolve(nil, substitutions)).to be_nil
    end

    it 'replaces a text mention by a text node carrying the mention marks' do
      json = doc({ type: 'paragraph', content: [text('Bonjour '), name] })

      expect(described_class.resolve(json, substitutions)).to eq(
        doc({ type: 'paragraph', content: [text('Bonjour '), text('Paul', marks: [{ type: 'bold' }])] })
      )
    end

    it 'keeps the html_safe flag of a substitution' do
      json = doc({ type: 'paragraph', content: [name] })
      resolved = described_class.resolve(json, { 'name' => '<a>Paul</a>'.html_safe })

      expect(resolved[:content].first[:content].first[:text]).to be_html_safe
    end

    it 'stringifies non-string substitutions' do
      json = doc({ type: 'paragraph', content: [name] })

      expect(described_class.resolve(json, { 'name' => 42 })[:content].first[:content]).to eq([text('42', marks: [{ type: 'bold' }])])
    end

    it 'uses the --id-- placeholder for a missing substitution' do
      json = doc({ type: 'paragraph', content: [mention] })

      expect(described_class.resolve(json)[:content].first[:content]).to eq([text('--languages--')])
    end

    it 'splits the paragraph around a block presentation and keeps the paragraph attributes on both halves' do
      json = doc({ type: 'paragraph', attrs: { textAlign: 'center' }, content: [text('Avant '), mention, text(' après')] })

      expect(described_class.resolve(json, substitutions)).to eq(
        doc(
          { type: 'paragraph', attrs: { textAlign: 'center' }, content: [text('Avant ')] },
          presentation.to_tiptap_node,
          { type: 'paragraph', attrs: { textAlign: 'center' }, content: [text(' après')] }
        )
      )
    end

    it 'drops the empty runs around a mention at the start or the end, and an empty substitution' do
      json = doc({ type: 'paragraph', content: [mention, name, mention] })

      expect(described_class.resolve(json, substitutions.merge('name' => ''))).to eq(
        doc(presentation.to_tiptap_node, presentation.to_tiptap_node)
      )
    end

    it 'nests the block presentation inside the list item' do
      json = doc({ type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [text('Item '), mention] }] }] })

      expect(described_class.resolve(json, substitutions)).to eq(
        doc({ type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [text('Item ')] }, presentation.to_tiptap_node] }] })
      )
    end

    it 'degrades a block presentation to its text inside a title or a heading' do
      json = doc({ type: 'title', content: [mention] }, { type: 'heading', attrs: { level: 2 }, content: [text('Titre '), mention] })

      expect(described_class.resolve(json, substitutions)).to eq(
        doc({ type: 'title', content: [text('ruby, rust')] }, { type: 'heading', attrs: { level: 2 }, content: [text('Titre '), text('ruby, rust')] })
      )
    end

    it 'keeps an inline presentation in the paragraph and marks its text nodes' do
      motivation = { type: 'mention', attrs: { id: 'motivation', label: 'Motivation' }, marks: [{ type: 'bold' }] }
      json = doc({ type: 'paragraph', content: [text('Avant '), motivation, text(' après')] })
      resolved = described_class.resolve(json, { 'motivation' => ChampPresentations::MultilineTextPresentation.new("a\nb") })

      expect(resolved).to eq(
        doc({ type: 'paragraph', content: [text('Avant '), text('a', marks: [{ type: 'bold' }]), { type: 'hardBreak' }, text('b', marks: [{ type: 'bold' }]), text(' après')] })
      )
    end

    it 'degrades an inline presentation to its text inside a heading' do
      json = doc({ type: 'heading', attrs: { level: 2 }, content: [{ type: 'mention', attrs: { id: 'motivation', label: 'Motivation' } }] })
      resolved = described_class.resolve(json, { 'motivation' => ChampPresentations::MultilineTextPresentation.new("a\nb") })

      expect(resolved).to eq(doc({ type: 'heading', attrs: { level: 2 }, content: [text("a\nb")] }))
    end

    it 'leaves empty blocks and unknown nodes untouched' do
      json = doc({ type: 'paragraph' }, { type: 'pageBreak' }, { type: 'heading', attrs: { level: 3 } })

      expect(described_class.resolve(json, substitutions)).to eq(json)
    end
  end

  describe '.mentions_within' do
    it 'lists the mentions nested inside the given node types' do
      json = {
        type: 'doc',
        content: [
          { type: 'title', content: [{ type: 'mention', attrs: { id: 'tdc1', label: 'A' } }] },
          { type: 'paragraph', content: [{ type: 'mention', attrs: { id: 'tdc2', label: 'B' } }] },
          { type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'heading', attrs: { level: 2 }, content: [{ type: 'mention', attrs: { id: 'tdc3', label: 'C' } }] }] }] },
        ],
      }

      expect(described_class.mentions_within(json, ['title', 'heading'])).to eq([['tdc1', 'A'], ['tdc3', 'C']])
    end
  end

  describe '#used_tags' do
    it 'returns used tags' do
      expect(described_class.used_tags_and_libelle_for(json)).to eq(Set.new([['name', 'Nom'], ['languages', 'Langages']]))
    end
  end

  describe 'sanitization' do
    it 'escapes HTML tags in text content' do
      json = { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: '<script>alert(1)</script>' }] }] }
      expect(described_class.new.to_html(json, {})).to include('&lt;script&gt;')
    end

    it 'ignores unknown node types' do
      json = { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Hello' }] }, { type: 'script', content: [{ type: 'text', text: 'evil' }] }] }
      result = described_class.new.to_html(json, {})
      expect(result).to include('Hello')
      expect(result).not_to include('evil')
    end
  end

  describe '.to_texts_and_tags' do
    subject { described_class.new.to_texts_and_tags(json, substitutions) }

    context 'nominal' do
      let(:json) do
        {
          "content" => [
            { "type" => "paragraph", "content" => [{ "text" => "export_", "type" => "text" }, { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } }, { "text" => " .pdf", "type" => "text" }] },
          ],

        }.deep_symbolize_keys
      end

      context 'with substitutions' do
        let(:substitutions) { { "dossier_number" => "42" } }
        it 'returns texts_and_tags' do
          is_expected.to eq("export_42.pdf")
        end
      end

      context 'without substitutions' do
        let(:substitutions) { nil }

        it 'returns texts_and_tags' do
          is_expected.to eq("export_<span class='fr-tag fr-tag--sm'>numéro du dossier</span>.pdf")
        end
      end
    end

    context 'empty paragraph' do
      let(:json) { { content: [{ type: 'paragraph' }] } }
      let(:substitutions) { {} }

      it { is_expected.to eq('') }
    end

    context 'pageBreak node' do
      let(:substitutions) { {} }

      it 'renders a space between paragraphs separated by a pageBreak' do
        json = {
          type: 'doc',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'Avant' }] },
            { type: 'pageBreak' },
            { type: 'paragraph', content: [{ type: 'text', text: 'Après' }] },
          ],
        }
        expect(described_class.new.to_texts_and_tags(json)).to eq('Avant Après')
      end
    end
  end

  describe '.to_texts_and_tags avec strip: false (rendu texte des sujets d’email)' do
    let(:doc) do
      {
        type: 'doc',
        content: [
          {
            type: 'paragraph',
            content: [
              { type: 'text', text: 'Dossier nº ' },
              { type: 'mention', attrs: { id: 'dossier_number', label: 'numéro du dossier' } },
              { type: 'text', text: ' reçu' },
            ],
          },
        ],
      }
    end

    it 'concatène le texte en préservant les espaces et substitue les mentions' do
      result = TiptapService.new.to_texts_and_tags(doc, { 'dossier_number' => '42' }, strip: false)
      expect(result).to eq('Dossier nº 42 reçu')
    end

    it 'affiche --id-- pour une mention absente des substitutions' do
      result = TiptapService.new.to_texts_and_tags(doc, { 'autre' => 'x' }, strip: false)
      expect(result).to eq('Dossier nº --dossier_number-- reçu')
    end

    it 'ignore un type de nœud inconnu' do
      doc[:content].first[:content] << { type: 'hardBreak' }
      result = TiptapService.new.to_texts_and_tags(doc, { 'dossier_number' => '42' }, strip: false)
      expect(result).to eq('Dossier nº 42 reçu')
    end
  end
end
