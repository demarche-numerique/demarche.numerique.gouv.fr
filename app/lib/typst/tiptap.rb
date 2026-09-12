# frozen_string_literal: true

module Typst
  # The body of an attestation v2, a tiptap document whose mentions
  # TiptapService.resolve replaced by their values, as the block/inline tree
  # the Typst theme renders (theme.typ attestation-body). Layout stays in the
  # theme: this walk only normalizes what the editor lets through and what
  # PDF/UA-1 refuses.
  #
  # Blocks: { type: 'header', columns: [[block]] }
  #         { type: 'heading', level: 1.., style: 'title' | 'section' | 'subsection', align:, content: [inline] }
  #         { type: 'paragraph', align:, content: [inline] }
  #         { type: 'list', ordered: bool, start: int, items: [[block]] }
  #         { type: 'details', rows: [[term, text]] } (a repetition row)
  #         { type: 'pagebreak' }
  # Inlines are those of Typst::RichText: text, linebreak, strong, emph, underline.
  #
  # - Headings are renumbered to their depth in the outline (the title is the
  #   h1, the first heading an h2 whatever its editor level, and so on), as
  #   PDF/UA-1 refuses a skipped level; the style keeps what the admin picked
  #   in the editor (the title, a heading, a sub-heading), so the letter
  #   looks as authored whatever its outline. A heading left blank once its
  #   mentions are resolved is dropped, as an empty heading is refused too.
  # - A page break inside a list item (refused in any container) moves after
  #   the list; page breaks before the body are dropped, as in the HTML
  #   rendering.
  # - Whitespace collapses like HTML text, so a document pasted from a word
  #   processor lays out as it did: a blank paragraph takes no room (the
  #   editor shows one as a blank line, the HTML rendering skips it), a hard
  #   break is a blank line, the historical attestation rendering.
  # - Text alignment maps to left, center, right or justify.
  module Tiptap
    MARKS = { 'bold' => 'strong', 'italic' => 'emph', 'underline' => 'underline' }.freeze
    ALIGNMENTS = %w[left center right justify].freeze
    BODY_TYPES = %w[paragraph list details].freeze
    HARD_BREAK = [{ type: 'linebreak' }, { type: 'linebreak' }].freeze
    STYLES = { 1 => 'title', 2 => 'section' }.freeze

    module_function

    def from_document(document)
      return [] if document.nil?

      blocks = trim(blocks(document[:content]))
      number_headings(blocks)
      blocks
    end

    # Text of an inline run, the way a reader sees it (line breaks as spaces).
    def plain(content)
      content.map do |inline|
        case inline
        in type: 'text', text: then text
        in type: 'linebreak' then ' '
        in content: then plain(content)
        end
      end.join.squish
    end

    def blocks(content)
      Array(content).flat_map { block(it) }
    end

    def block(node)
      case node
      in type: 'header', content:
        columns = content.map { column(it) }
        columns.any?(&:present?) ? [{ type: 'header', columns: }] : []
      in type: 'title', content:
        heading(1, node, content)
      in type: 'heading', attrs: { level: }, content:
        heading(level, node, content)
      in type: 'paragraph'
        paragraph(node)
      in type: 'bulletList' | 'orderedList', content:
        list(node, content)
      in type: 'descriptionList', content:
        details(content)
      in type: 'pageBreak'
        [{ type: 'pagebreak' }]
      else
        # unknown node types
        []
      end
    end

    def column(node) = blocks(node[:content])

    def paragraph(node)
      inlines = inlines(node[:content])
      return [] if inlines.empty?

      [{ type: 'paragraph', align: align(node), content: inlines }]
    end

    def heading(level, node, content)
      inlines = inlines(content)
      return [] if plain(inlines).blank?

      [{ type: 'heading', level:, style: STYLES.fetch(level, 'subsection'), align: align(node), content: inlines }]
    end

    # Each item's page breaks move after the list (a page break inside a
    # container cannot be exported).
    def list(node, content)
      items = content.map { blocks(it[:content]) }
      broken = items.any? { |item| item.any? { it[:type] == 'pagebreak' } }
      items = items.map { |item| item.reject { it[:type] == 'pagebreak' } }
      start = node.dig(:attrs, :start).to_i
      list = { type: 'list', ordered: node[:type] == 'orderedList', start: [start, 1].max, items: }

      broken ? [list, { type: 'pagebreak' }] : [list]
    end

    # The description list of a repetition row (ChampPresentations): a row per
    # term/details pair, the ones of the champs left blank (marked invisible
    # for the HTML rendering) dropped.
    def details(content)
      rows = content.each_slice(2).filter_map do |term, description|
        next if term.nil? || description.nil? || term.dig(:attrs, :class) == 'invisible'

        [plain(inlines(term[:content])), plain(inlines(description[:content]))]
      end

      rows.empty? ? [] : [{ type: 'details', rows: }]
    end

    def align(node)
      alignment = node.dig(:attrs, :textAlign)
      ALIGNMENTS.include?(alignment) ? alignment : 'left'
    end

    # Inline run of a block: whitespace collapsed like HTML rendering, no
    # space left at the edges of a line; the text keeps its marks.
    def inlines(content)
      runs = Array(content).flat_map { it[:type] == 'hardBreak' ? HARD_BREAK : [it] }
      runs.each_with_index.filter_map do |node, index|
        next node if node[:type] != 'text'

        text = node[:text].to_s.gsub(/\s+/, ' ')
        text = text.lstrip if index == 0 || runs[index - 1][:type] == 'linebreak'
        text = text.rstrip if index == runs.size - 1 || runs[index + 1][:type] == 'linebreak'
        marked({ type: 'text', text: }, node[:marks]) if !text.empty?
      end
    end

    def marked(inline, marks)
      Array(marks).filter_map { MARKS[it[:type]] }.reduce(inline) { |content, type| { type:, content: [content] } }
    end

    # No page break before the first body block (the header and the title
    # are not body: a leading page break would open with a blank page); a
    # trailing one keeps pushing the signature to its own page.
    def trim(blocks)
      first_body = blocks.index { body?(it) }
      blocks.reject.with_index { |block, index| block[:type] == 'pagebreak' && (first_body.nil? || index < first_body) }
    end

    def body?(block) = block[:type].in?(BODY_TYPES) || (block[:type] == 'heading' && block[:level] > 1)

    # Heading levels as the depth of the outline they form in document order:
    # a deeper editor level nests under the previous heading, a shallower or
    # equal one goes back up to its parent's depth.
    def number_headings(blocks)
      stack = []
      headings(blocks).each do |heading|
        stack.pop while stack.any? && stack.last[0] >= heading[:level]
        depth = stack.empty? ? 1 : stack.last[1] + 1
        stack << [heading[:level], depth]
        heading[:level] = depth
      end
    end

    def headings(blocks)
      blocks.flat_map do |block|
        case block
        in type: 'heading' then [block]
        in type: 'header', columns: then columns.flat_map { headings(it) }
        in type: 'list', items: then items.flat_map { headings(it) }
        else []
        end
      end
    end
  end
end
