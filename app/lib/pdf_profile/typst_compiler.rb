# frozen_string_literal: true

module PdfProfile
  # Compiles profile-conformant HTML (config/pdf_profile.yml) to Typst markup
  # built on lib/typst/theme.typ. Deliberately strict: any element, class or
  # structure outside the implemented subset raises, so a template change
  # either compiles everywhere or fails loudly - never silently drops styling.
  #
  # Skeleton scope: the attestation de depot family, plus the profile's shared
  # inline grammar (strong/em/u/mark/a/br). Extend handler by handler as
  # document families are migrated.
  class TypstCompiler
    class Error < StandardError; end

    # Characters with markup meaning in Typst prose. (# and $ are
    # backslash-escaped so Ruby does not read #$... as interpolation.)
    TYPST_SPECIALS = /[\\\#\$&@*_`<>~\[\]]/

    def self.compile(html, assets: {}) = new(assets:).compile(html)

    def initialize(assets: {})
      @assets = assets
    end

    def compile(html)
      doc = Nokogiri::HTML5(html)
      body = doc.at_css('body') || raise(Error, 'document has no <body>')
      title = doc.at_css('head > title')&.text&.strip
      lang = doc.at_css('html')&.attr('lang') || 'fr'

      preamble = <<~TYP
        #import "theme.typ": *
        #show: conf.with(title: #{string(title)}, lang: #{string(lang)})
      TYP

      "#{preamble}\n#{blocks(body)}\n"
    end

    private

    def blocks(node)
      node.element_children.map { block(it) }.join("\n\n")
    end

    def block(node)
      raise Error, "style attribute not implemented for <#{node.name}>" if node['style']

      case [node.name, node.classes.sort]
      in ['div', ['a4-container', *]] | ['div', ['content']] | ['div', ['main']]
        blocks(node)
      in ['header', [*, 'first-header', *]]
        first_header(node)
      in ['div', ['bloc-marque']]
        "#bloc-marque[#{blocks(node)}]"
      in ['div', ['logo-site']]
        "#logo-site[#{blocks(node)}]"
      in ['div', ['direction-block']]
        "#direction-block[\n#{blocks(node)}\n]"
      in ['p', ['direction-label']]
        "#direction-label[#{inline_content(node)}]"
      in ['p', ['direction-site']]
        "#direction-site[#{inline_content(node)}]"
      in ['h1', ['attestation-depot-title']]
        "#depot-title[#{inline_content(node)}]"
      in ['h2', []]
        "#heading(level: 2)[#{inline_content(node)}]"
      in ['p', ['attestation-depot-procedure']]
        "#depot-procedure[#{inline_content(node)}]"
      in ['p', ['attestation-depot-description']]
        "#depot-description[#{inline_content(node)}]"
      in ['p', []]
        "#par[#{inline_content(node)}]"
      in ['section', ['attestation-depot-section']]
        "#depot-section[\n#{blocks(node)}\n]"
      in ['dl', []]
        key_value(node)
      in ['div', ['signature']]
        "#signature[\n#{blocks(node)}\n]"
      in ['img', classes]
        image(node, classes)
      else
        raise Error, "unsupported element <#{node.name} class=\"#{node.classes.join(' ')}\"> - extend the compiler or fix the template"
      end
    end

    def first_header(node)
      left = child_by_class(node, 'left')
      right = child_by_class(node, 'right')

      "#first-header(\n[\n#{blocks(left)}\n],\n[\n#{blocks(right)}\n],\n)"
    end

    IMAGE_HEIGHTS = {
      'marianne-with-devise' => '20mm', # attestation.scss .marianne-with-devise
      nil => '15mm', # .logo-site img
    }.freeze

    def image(node, classes)
      alt = node['alt'].to_s
      raise Error, "<img> without alt text (#{node['src']})" if alt.blank?

      height = IMAGE_HEIGHTS.fetch(classes.first) do
        raise Error, "<img class=\"#{classes.join(' ')}\"> has no height mapping"
      end

      path = @assets[node['src']]
      arguments = [("path: #{string(path)}" if path), "alt: #{string(alt)}", "height: #{height}"].compact

      "#profile-image(#{arguments.join(', ')})"
    end

    def key_value(node)
      pairs = []

      node.element_children.each do |child|
        case child.name
        when 'dt'
          pairs << [inline_content(child), nil]
        when 'dd'
          raise Error, '<dd> without a preceding <dt>' if pairs.empty? || !pairs.last[1].nil?

          pairs.last[1] = inline_content(child)
        else
          raise Error, "unexpected <#{child.name}> in <dl>"
        end
      end

      raise Error, '<dt> without a <dd>' if pairs.any? { it[1].nil? }

      arguments = pairs.map { |term, description| "  ([#{term}], [#{description}])," }.join("\n")
      "#key-value(\n#{arguments}\n)"
    end

    def inline_content(node)
      node.children.map { inline(it) }.join.strip
    end

    def inline(node)
      return escape(node.text) if node.text?
      raise Error, "unexpected #{node.name} node in inline content" unless node.element?

      case [node.name, node.classes]
      in ['strong', []] then "#strong[#{inline_content(node)}]"
      in ['em', []] then "#emph[#{inline_content(node)}]"
      in ['u', []] then "#underline[#{inline_content(node)}]"
      in ['mark', []] then "#highlight[#{inline_content(node)}]"
      in ['a', []] then "#link(#{string(node['href'])})[#{inline_content(node)}]"
      in ['br', []] then "#linebreak()"
      else
        raise Error, "unsupported inline element <#{node.name} class=\"#{node.classes.join(' ')}\">"
      end
    end

    def child_by_class(node, css_class)
      node.element_children.find { it.classes.include?(css_class) } ||
        raise(Error, "expected a .#{css_class} child in <#{node.name} class=\"#{node.classes.join(' ')}\">")
    end

    # Text with Typst markup characters escaped, whitespace collapsed.
    def escape(text)
      text.gsub(/\s+/, ' ').gsub(TYPST_SPECIALS) { "\\#{it}" }
    end

    # A Typst string literal (backslashes and quotes escaped in one pass).
    def string(text)
      escaped = text.to_s.gsub(/["\\]/) { "\\#{it}" }
      "\"#{escaped}\""
    end
  end
end
