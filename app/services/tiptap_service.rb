# frozen_string_literal: true

class TiptapService
  BODY_START_CLASS = 'body-start'

  # Level-0 nodes that can open the body of an attestation (everything after
  # the header and the title).
  BODY_BLOCK_TYPES = ['paragraph', 'heading', 'bulletList', 'orderedList', 'descriptionList'].freeze

  # Inline nodes of the tiptap schema, every other node is a block.
  INLINE_TYPES = ['text', 'hardBreak'].freeze

  # NOTE: node must be deep symbolized keys
  def self.used_tags_and_libelle_for(node, tags = Set.new)
    case node
    in type: 'mention', attrs: { id:, label: }, **rest
      tags << [id, label]
    in { content:, **rest } if content.is_a?(Array)
      content.each { used_tags_and_libelle_for(_1, tags) }
    else
      # ignore unknown node types
    end

    tags
  end

  # Replaces every mention by its substitution and returns a document that
  # follows the tiptap schema, so that renderers (HTML, Typst) never have to
  # know about mentions:
  # - a text substitution becomes a text node carrying the mention marks
  #   (the string keeps its `html_safe?` flag, so an HTML renderer escapes
  #   exactly what the substitution layer did not);
  # - a presentation becomes its tiptap nodes: inline ones (multiline text)
  #   stay in the paragraph, their text nodes carrying the mention marks;
  #   block ones (the lists of a repetition, a multiple drop down or a carte)
  #   split the enclosing paragraph, every inline run keeping the paragraph
  #   attributes and empty runs being dropped; inside a title or a heading,
  #   which cannot hold a block, a presentation degrades to its text;
  # - a missing substitution becomes the "--id--" placeholder.
  def self.resolve(node, substitutions = {})
    return nil if node.nil?

    node.merge(content: resolve_blocks(node[:content], substitutions))
  end

  def self.resolve_blocks(content, substitutions)
    content.flat_map { resolve_block(it, substitutions) }
  end

  def self.resolve_block(node, substitutions)
    case node
    in type: 'paragraph', content:
      content
        .flat_map { resolve_inline(it, substitutions) }
        .reject { empty_text?(it) }
        .slice_when { |a, b| block?(a) || block?(b) }
        .map { block?(it.first) ? it.first : node.merge(content: it) }
    in type: 'title' | 'heading', content:
      [node.merge(content: content.flat_map { resolve_inline(it, substitutions, text_only: true) })]
    in { content: } if content.is_a?(Array)
      [node.merge(content: resolve_blocks(content, substitutions))]
    else
      [node]
    end
  end

  def self.resolve_inline(node, substitutions, text_only: false)
    case node
    in type: 'mention', attrs: { id: }, **rest
      value = substitutions.fetch(id) { "--#{id}--" }
      nodes = if value.respond_to?(:to_tiptap_nodes) && !text_only
        value.to_tiptap_nodes
      else
        [{ type: 'text', text: value.to_s }]
      end
      marks = rest[:marks]
      marks.present? ? nodes.map { it[:type] == 'text' ? it.merge(marks:) : it } : nodes
    else
      [node]
    end
  end

  def self.block?(node) = !node[:type].in?(INLINE_TYPES)

  def self.empty_text?(node)
    node in { type: 'text', text: '' }
  end

  private_class_method :resolve_blocks, :resolve_block, :resolve_inline, :block?, :empty_text?

  def to_html(node, substitutions = {})
    return '' if node.nil?

    children(self.class.resolve(node, substitutions)[:content], 0)
  end

  def to_texts_and_tags(node, substitutions = {}, strip: true)
    return '' if node.nil?

    children_texts_and_tags(node[:content], substitutions, strip)
  end

  private

  def initialize(hard_break: "<br>")
    @body_started = false
    @hard_break = hard_break
  end

  def children_texts_and_tags(content, substitutions, strip)
    content.map { node_to_texts_and_tags(_1, substitutions, strip) }.join
  end

  def node_to_texts_and_tags(node, substitutions, strip)
    case node
    in type: 'paragraph', content:
      children_texts_and_tags(content, substitutions, strip)
    in type: 'paragraph' # empty paragraph
      ''
    in type: 'text', text:
      strip ? text.strip : text
    in type: 'mention', attrs: { id:, label: }
      if substitutions.present?
        substitutions.fetch(id) { "--#{id}--" }
      else
        "<span class='fr-tag fr-tag--sm'>#{label}</span>"
      end
    in type: 'pageBreak'
      ' '
    else
      # ignore unknown node types
      ''
    end
  end

  def children(content, level)
    content.map { node_to_html(_1, level) }.join
  end

  # List items are rendered without their inner paragraph (PDF/UA).
  def list_item_body(content, level)
    content.map do |node|
      case node
      in type: 'paragraph', content: paragraph_content
        children(paragraph_content, level + 1)
      in type: 'paragraph' # empty paragraph
        ''
      else
        node_to_html(node, level)
      end
    end.join
  end

  def node_to_html(node, level)
    body_start = level == 0 && !@body_started && node[:type].in?(BODY_BLOCK_TYPES) && node.key?(:content)
    @body_started = true if body_start

    case node
    in type: 'header', content:
      "<header>#{children(content, level + 1)}</header>"
    in type: 'footer', content:, **rest
      "<footer#{text_align(rest[:attrs])}>#{children(content, level + 1)}</footer>"
    in type: 'headerColumn', content:, **rest
      "<div#{text_align(rest[:attrs])}>#{children(content, level + 1)}</div>"
    in type: 'paragraph', content:, **rest
      "<p#{class_list(nil, body_start)}#{text_align(rest[:attrs])}>#{children(content, level + 1)}</p>"
    in type: 'title', content:, **rest
      "<h1#{text_align(rest[:attrs])}>#{children(content, level + 1)}</h1>"
    in type: 'heading', attrs: { level: hlevel, **attrs }, content:
      "<h#{hlevel}#{class_list(nil, body_start)}#{text_align(attrs)}>#{children(content, level + 1)}</h#{hlevel}>"
    in type: 'bulletList', content:, **rest
      "<ul#{class_list(rest[:attrs], body_start)}>#{children(content, level + 1)}</ul>"
    in type: 'orderedList', content:, **rest
      "<ol#{class_list(rest[:attrs], body_start)}>#{children(content, level + 1)}</ol>"
    in type: 'listItem', content:
      "<li>#{list_item_body(content, level + 1)}</li>"
    in type: 'descriptionList', content:
      "<dl#{class_list(nil, body_start)}>#{children(content, level + 1)}</dl>"
    in type: 'descriptionTerm', content:, **rest
      "<dt#{class_list(rest[:attrs])}>#{children(content, level + 1)}</dt>"
    in type: 'descriptionDetails', content:
      "<dd>#{children(content, level + 1)}</dd>"
    in type: 'hardBreak'
      @hard_break
    in type: 'text', text:, **rest
      escaped = ERB::Util.html_escape(text)
      if rest[:marks].present?
        apply_marks(escaped, rest[:marks])
      else
        escaped
      end
    in type: 'pageBreak'
      level == 0 && !@body_started ? '' : '<div class="page-break"></div>'
    else
      # empty blocks and unknown node types
      ''
    end
  end

  def text_align(attrs)
    if attrs.present? && attrs[:textAlign].present?
      " style=\"text-align: #{attrs[:textAlign]}\""
    else
      ""
    end
  end

  def class_list(attrs, body_start = false)
    classes = [attrs&.dig(:class).presence, (BODY_START_CLASS if body_start)].compact
    " class=\"#{classes.join(' ')}\"" if classes.any?
  end

  def apply_marks(text, marks)
    marks.reduce(text) do |text, mark|
      case mark
      in type: 'bold'
        "<strong>#{text}</strong>"
      in type: 'italic'
        "<em>#{text}</em>"
      in type: 'underline'
        "<u>#{text}</u>"
      in type: 'highlight'
        "<mark>#{text}</mark>"
      in type: 'link', attrs: { href: }
        "<a href=\"#{ERB::Util.html_escape(href)}\" target=\"_blank\" rel=\"noopener noreferrer\">#{text}</a>"
      end
    end
  end
end
