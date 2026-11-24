# frozen_string_literal: true

module Typst
  # Admin-authored Markdown (procedure and champ descriptions) as a small
  # JSON-able tree the Typst theme renders natively (theme.typ rich-text): the
  # text is rendered by the same SimpleFormatComponent as the web form, so the
  # paper form shows exactly what the usager sees on screen and the sanitizer
  # is reused, then the sanitized HTML is walked into blocks and inlines.
  #
  # Blocks: { type: 'paragraph', content: [inline] }
  #         { type: 'list', ordered: bool, start: int, items: [[inline]] }
  # Inlines: { type: 'text', text: }, { type: 'linebreak' },
  #          { type: 'strong' | 'emph' | 'underline', content: [inline] },
  #          { type: 'link', href:, content: [inline], spell: url-or-nil }
  #
  # Authored headings become bold paragraphs: the document outline (and the
  # PDF/UA heading hierarchy typst enforces) belongs to the template.
  module RichText
    BLOCK_TAGS = %w[p ul ol li blockquote h1 h2 h3 h4 h5 h6 div].freeze
    MARK_TAGS = { 'strong' => 'strong', 'b' => 'strong', 'em' => 'emph', 'i' => 'emph', 'u' => 'underline' }.freeze

    module_function

    def from_markdown(text)
      return if text.blank?

      html = ApplicationController.render(SimpleFormatComponent.new(text, allow_a: true), layout: false)
      blocks(Nokogiri::HTML.fragment(html)).presence
    end

    def blocks(node)
      return [] if node.comment?
      return [paragraph(trim(inline(node)))].compact if node.text?

      case node.name
      when 'ul', 'ol'
        [list_block(node)].compact
      when '#document-fragment', 'blockquote', 'div'
        node.children.any? { block?(it) } ? node.children.flat_map { blocks(it) } : [paragraph(inlines(node))].compact
      when /\Ah[1-6]\z/
        [paragraph(inlines(node), mark: 'strong')].compact
      else
        [paragraph(inlines(node))].compact
      end
    end

    def list_block(node)
      list_items = node.xpath('./li')
      items = list_items.map { inlines(it).presence }.compact
      return if items.empty?

      first_value = list_items.first['value'].to_i
      { type: 'list', ordered: node.name == 'ol', start: [first_value, 1].max, items: }
    end

    def paragraph(content, mark: nil)
      return if content.empty?

      { type: 'paragraph', content: mark ? [{ type: mark, content: }] : content }
    end

    # Inline run of a block: whitespace collapsed like HTML rendering, leading
    # and trailing whitespace and line breaks trimmed.
    def inlines(node)
      trim(node.children.flat_map { inline(it) })
    end

    def inline(node)
      if node.text?
        text = node.text.gsub(/\s+/, ' ')
        text.empty? ? [] : [{ type: 'text', text: }]
      elsif node.comment?
        []
      elsif node.name == 'br'
        [{ type: 'linebreak' }]
      elsif node.name == 'a' && node['href'].present?
        link(node)
      elsif MARK_TAGS.key?(node.name)
        content = trim(node.children.flat_map { inline(it) })
        content.empty? ? [] : [{ type: MARK_TAGS.fetch(node.name), content: }]
      else
        node.children.flat_map { inline(it) }
      end
    end

    # On paper the URL itself is the information: a link whose label is not
    # its target is followed by the spelled-out target. A URL label is left as
    # plain text for the template's URL show rule, so links never nest. An
    # empty anchor (Redcarpet autolinks the URL out of an authored <a>, leaving
    # the tag empty) renders nothing, like on the web.
    def link(node)
      href = node['href'].strip
      label = node.text.strip

      return [] if label.blank?
      return [{ type: 'text', text: href }] if label == href

      spell = href.delete_prefix('mailto:') == label ? nil : href
      [{ type: 'link', href:, content: trim(node.children.flat_map { inline(it) }), spell: }]
    end

    def block?(node) = node.element? && node.name.in?(BLOCK_TAGS)

    def trim(content)
      content = content.drop_while { it[:type] == 'linebreak' }.reverse.drop_while { it[:type] == 'linebreak' }.reverse
      return content if content.empty?

      strip_edge(content.first, :lstrip)
      strip_edge(content.last, :rstrip)
      content.reject { it[:type] == 'text' && it[:text].empty? }
    end

    def strip_edge(node, method)
      node[:text] = node[:text].public_send(method) if node[:type] == 'text'
    end
  end
end
