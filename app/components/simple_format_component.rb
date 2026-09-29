# frozen_string_literal: true

class SimpleFormatComponent < ApplicationComponent
  # see: https://github.com/vmg/redcarpet#and-its-like-really-simple-to-use
  REDCARPET_EXTENSIONS = {
    no_intra_emphasis: true,
    disable_indented_code_blocks: true,
    space_after_headers: true,
    tables: false,
    fenced_code_blocks: false,
    autolink: false,
    strikethrough: false,
    lax_spacing: false,
    superscript: false,
    underline: false,
    highlight: false,
    quote: false,
    footnotes: false,
  }

  # see: https://github.com/vmg/redcarpet#darling-i-packed-you-a-couple-renderers-for-lunch
  REDCARPET_RENDERER_OPTS = {
    no_images: true,
  }

  SIMPLE_URL_REGEX = %r{https?://[^\s<>]+}
  EMAIL_IN_TEXT_REGEX = Regexp.new(StrictEmailValidator::REGEXP.source.gsub(/\\A|\\z/, '\b'))

  def initialize(text, allow_a: true, allow_autolink: true, class_names_map: {})
    @allow_a = allow_a
    @allow_autolink = allow_a || allow_autolink

    # Logic for html links/autolinks:
    # Sometimes we want to allow autolinking of urls, without allowing html/markdown links from users.
    # Because we sanitize the rendered markdown, when html links are not allowed, we can't enable redcarpet autolink
    # (it would be sanitized), so we manually autolink after sanitization.
    # At the contrary, when links are allowed, autolinking is always made with redcarpet.

    list_item = false
    lines = (text || "")
      .lines
      .map(&:lstrip) # this block prevent redcarpet to consider "   text" as block code by lstriping

    @text = lines.map do |line|
      item_number = line.match(/\A(\d+)\./)
      if item_number.present?
        list_item = true
        "\n" + line + "[value:#{item_number[1]}]"
      elsif line.match?(/\A[-*+]\s/)
        list_item = true
        "\n" + line
      elsif line == ''
        list_item = false
        "\n" + line
      elsif list_item
        line
      else
        "\n" + line
      end
    end.join.lstrip

    @renderer = Redcarpet::Markdown.new(
      Redcarpet::BareRenderer.new(class_names_map: class_names_map.merge(list: 'fr-ol-content--override')),
      REDCARPET_EXTENSIONS.merge(autolink: @allow_a)
    )
  end

  # `gsub` drops the html_safe flag of the sanitized markup, and `link_to` escapes
  # the urls it splices in: putting the flag back is safe.
  def autolink(sanitized_html)
    return sanitized_html if !@allow_autolink
    return sanitized_html if @allow_a # already autolinked

    linked = sanitized_html.gsub(SIMPLE_URL_REGEX) do |url|
      # The URL matched in the HTML is already escaped (& becomes &amp;)
      # We need to unescape it before passing to link_to, which will escape it again correctly
      # This prevents double-encoding: &amp; -> &amp;amp;
      unescaped_url = CGI.unescapeHTML(url)
      helpers.link_to(unescaped_url, unescaped_url, **helpers.external_link_attributes)
    end

    linked.html_safe # rubocop:disable Rails/OutputSafety
  end

  def tags
    if @allow_a
      Rails.configuration.action_view.sanitized_allowed_tags + ['a']
    else
      Rails.configuration.action_view.sanitized_allowed_tags
    end
  end

  def attributes
    ['target', 'rel', 'href', 'class', 'title', 'value']
  end
end
