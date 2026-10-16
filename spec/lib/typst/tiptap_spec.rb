# frozen_string_literal: true

describe Typst::Tiptap do
  def text(text, marks: nil) = { type: 'text', text:, **{ marks: }.compact }
  def paragraph(*content, align: nil) = { type: 'paragraph', **{ attrs: ({ textAlign: align } if align) }.compact, content: }
  def heading(level, *content) = { type: 'heading', attrs: { level: }, content: }
  def title(*content) = { type: 'title', attrs: { textAlign: 'center' }, content: }
  def item(*content) = { type: 'listItem', content: }
  def document(*content) = { type: 'doc', content: }

  def blocks(*content) = described_class.from_document(document(*content))

  it 'renders nothing for a missing document' do
    expect(described_class.from_document(nil)).to eq([])
  end

  describe 'blocks' do
    it 'lays the header out as columns' do
      header = {
        type: 'header',
        content: [
          { type: 'headerColumn', content: [paragraph(text('Service instructeur')), paragraph] },
          { type: 'headerColumn', content: [paragraph(text('Fait le 3 mai 2026'), align: 'right')] },
        ],
      }

      expect(blocks(header, paragraph(text('Corps')))).to eq([
        {
          type: 'header',
          columns: [
            [{ type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'Service instructeur' }] }],
            [{ type: 'paragraph', align: 'right', content: [{ type: 'text', text: 'Fait le 3 mai 2026' }] }],
          ],
        },
        { type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'Corps' }] },
      ])
    end

    it 'drops a header whose columns are all blank' do
      header = { type: 'header', content: [{ type: 'headerColumn', content: [paragraph] }, { type: 'headerColumn', content: [paragraph(text(' '))] }] }

      expect(blocks(header, paragraph(text('Corps'))).map { it[:type] }).to eq(['paragraph'])
    end

    it 'renders the title as the level 1 heading, with its alignment' do
      expect(blocks(title(text('Attestation')))).to eq([
        { type: 'heading', level: 1, style: 'title', align: 'center', content: [{ type: 'text', text: 'Attestation' }] },
      ])
    end

    # (the HTML rendering skips them too: the editor's blank lines never
    # reached the PDF)
    it 'drops blank paragraphs' do
      expect(blocks(paragraph(text('a')), paragraph, paragraph(text(' ')), { type: 'paragraph', content: [] }, paragraph(text('b')))).to eq([
        { type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'a' }] },
        { type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'b' }] },
      ])
    end

    it 'maps the text alignment, an unknown value (pasted "start") to the left' do
      expect(blocks(paragraph(text('a'), align: 'justify'), paragraph(text('b'), align: 'start'), paragraph(text('c'))).map { it[:align] })
        .to eq(['justify', 'left', 'left'])
    end

    it 'renders lists with their items as blocks, honouring the start of a numbered list' do
      bullets = { type: 'bulletList', content: [item(paragraph(text('un'))), item(paragraph(text('deux')), { type: 'bulletList', content: [item(paragraph(text('deux bis')))] })] }
      numbers = { type: 'orderedList', attrs: { start: 3 }, content: [item(paragraph(text('trois')))] }

      expect(blocks(bullets, numbers)).to eq([
        {
          type: 'list', ordered: false, start: 1, items: [
            [{ type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'un' }] }],
            [
              { type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'deux' }] },
              { type: 'list', ordered: false, start: 1, items: [[{ type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'deux bis' }] }]] },
            ],
          ],
        },
        { type: 'list', ordered: true, start: 3, items: [[{ type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'trois' }] }]] },
      ])
    end

    it 'renders the rows of a repetition as details, dropping the blank champs' do
      repetition = {
        type: 'orderedList', attrs: { class: 'tdc-repetition' }, content: [
          item({
            type: 'descriptionList', content: [
              { type: 'descriptionTerm', content: [text('Nom')] }, { type: 'descriptionDetails', content: [text('Dupont')] },
              { type: 'descriptionTerm', attrs: { class: 'invisible' }, content: [text('Prénom')] }, { type: 'descriptionDetails', content: [text('')] },
            ],
          }),
          item({ type: 'descriptionList', content: [{ type: 'descriptionTerm', attrs: { class: 'invisible' }, content: [text('Nom')] }, { type: 'descriptionDetails', content: [text('')] }] }),
        ],
      }

      expect(blocks(repetition)).to eq([
        { type: 'list', ordered: true, start: 1, items: [[{ type: 'details', rows: [['Nom', 'Dupont']] }], []] },
      ])
    end

    it 'ignores unknown node types' do
      expect(blocks({ type: 'footer', content: [paragraph(text('x'))] }, paragraph(text('a'))).map { it[:type] }).to eq(['paragraph'])
    end
  end

  describe 'inlines' do
    it 'nests the marks of a text, ignoring unknown ones' do
      content = blocks(paragraph(text('gras', marks: [{ type: 'bold' }]), text(' et '), text('mixte', marks: [{ type: 'italic' }, { type: 'bold' }, { type: 'highlight' }]))).first[:content]

      expect(content).to eq([
        { type: 'strong', content: [{ type: 'text', text: 'gras' }] },
        { type: 'text', text: ' et ' },
        { type: 'strong', content: [{ type: 'emph', content: [{ type: 'text', text: 'mixte' }] }] },
      ])
    end

    it 'renders a hard break as a blank line and collapses whitespace like HTML' do
      content = blocks(paragraph(text("  Fait à\tParis,   le "), { type: 'hardBreak' }, text(' 3 mai  '), text('2026 '))).first[:content]

      expect(content).to eq([
        { type: 'text', text: 'Fait à Paris, le' },
        { type: 'linebreak' },
        { type: 'linebreak' },
        { type: 'text', text: '3 mai ' },
        { type: 'text', text: '2026' },
      ])
    end

    it 'keeps non-breaking spaces, the admins indent with them' do
      content = blocks(paragraph(text("  Indenté  "))).first[:content]

      expect(content).to eq([{ type: 'text', text: "  Indenté" }])
    end

    it 'keeps a paragraph made of hard breaks only as spacing' do
      expect(blocks(paragraph({ type: 'hardBreak' }), paragraph(text('a'))).first[:content]).to eq([{ type: 'linebreak' }, { type: 'linebreak' }])
    end
  end

  describe 'headings' do
    it 'numbers the headings by their depth in the outline under the title' do
      expect(blocks(title(text('T')), heading(3, text('a')), heading(2, text('b')), heading(3, text('c')), heading(3, text('d')), heading(2, text('e'))).map { it[:level] })
        .to eq([1, 2, 2, 3, 3, 2])
    end

    it 'starts the outline at the first heading without a title' do
      expect(blocks(heading(3, text('a')), heading(2, text('b')), heading(3, text('c'))).map { it[:level] }).to eq([1, 1, 2])
    end

    it 'keeps the style picked in the editor whatever the outline' do
      expect(blocks(title(text('T')), heading(3, text('a')), heading(2, text('b')), heading(4, text('c'))).map { it.values_at(:level, :style) })
        .to eq([[1, 'title'], [2, 'subsection'], [2, 'section'], [3, 'subsection']])
    end

    it 'numbers the headings nested in list items in document order' do
      list = { type: 'bulletList', content: [item(heading(3, text('dans la liste')))] }

      expect(blocks(title(text('T')), list, heading(3, text('après'))).filter_map { it[:items]&.first&.first&.fetch(:level) || it[:level] }).to eq([1, 2, 2])
    end

    it 'drops a heading left blank once its mentions are resolved' do
      expect(blocks(title(text(" ")), heading(2, text('')), heading(2, text(' '), { type: 'hardBreak' }), heading(3, text('Reste'))))
        .to eq([{ type: 'heading', level: 1, style: 'subsection', align: 'left', content: [{ type: 'text', text: 'Reste' }] }])
    end

    it 'keeps the marks and line breaks of a heading' do
      expect(blocks(heading(2, text('Article', marks: [{ type: 'bold' }]), { type: 'hardBreak' }, text('1er'))).first[:content]).to eq([
        { type: 'strong', content: [{ type: 'text', text: 'Article' }] },
        { type: 'linebreak' },
        { type: 'linebreak' },
        { type: 'text', text: '1er' },
      ])
    end
  end

  describe 'page breaks' do
    it 'keeps a page break between body blocks' do
      expect(blocks(paragraph(text('a')), { type: 'pageBreak' }, paragraph(text('b'))).map { it[:type] }).to eq(['paragraph', 'pagebreak', 'paragraph'])
    end

    it 'drops the page breaks before the body, keeping a trailing one for the signature' do
      header = { type: 'header', content: [{ type: 'headerColumn', content: [paragraph(text('Service'))] }] }

      expect(blocks({ type: 'pageBreak' }, header, title(text('T')), { type: 'pageBreak' }, paragraph(text('a')), { type: 'pageBreak' }, paragraph).map { it[:type] })
        .to eq(['header', 'heading', 'paragraph', 'pagebreak'])
    end

    it 'moves a page break out of a list item, after the list' do
      list = { type: 'bulletList', content: [item(paragraph(text('un')), { type: 'pageBreak' }), item(paragraph(text('deux')))] }

      expect(blocks(list, paragraph(text('suite')))).to eq([
        { type: 'list', ordered: false, start: 1, items: [[{ type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'un' }] }], [{ type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'deux' }] }]] },
        { type: 'pagebreak' },
        { type: 'paragraph', align: 'left', content: [{ type: 'text', text: 'suite' }] },
      ])
    end
  end

  describe '.plain' do
    it 'reads an inline run as text' do
      expect(described_class.plain([{ type: 'strong', content: [{ type: 'text', text: 'a' }] }, { type: 'linebreak' }, { type: 'text', text: ' b' }])).to eq('a b')
    end
  end
end
