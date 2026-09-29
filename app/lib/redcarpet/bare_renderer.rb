# frozen_string_literal: true

module Redcarpet
  class BareRenderer < Redcarpet::Render::HTML
    include ActionView::Helpers::TagHelper
    include ApplicationHelper

    # won't use rubocop tag method because it is missing output buffer
    def list(content, list_type)
      tag = list_type == :ordered ? :ol : :ul
      content_tag(tag, content, { class: @options[:class_names_map].fetch(:list) {} }, false)
    end

    def list_item(content, list_type)
      item_number = content.match(/\[value:(\d+)\]/)
      text = content.strip
        .gsub(/<\/?p>/, '')
        .gsub(/\[value:\d+\]/, '')
        .gsub(/\n/, '<br>')
      attributes = item_number.present? ? { value: item_number[1] } : {}

      content_tag(:li, text, attributes, false)
    end

    def paragraph(text)
      content_tag(:p, text, { class: @options[:class_names_map].fetch(:paragraph) {} }, false)
    end

    def link(href, title, content)
      content_tag(:a, content, { href:, **external_link_attributes(title) }, false)
    end

    # Redcarpet's C scanner ends an autolink on isalnum(), which on macOS in a
    # UTF-8 locale accepts the lead byte of the character following the address
    # (a no-break space before a colon, an accented letter, a « ») and hands us
    # a link with a stray byte that Rails then rejects as invalid UTF-8. glibc
    # does not classify those bytes, so production is unaffected. Link the valid
    # prefix and put the stray bytes back after it, where Redcarpet emits the
    # rest of the character: the output bytes are the intended ones.
    def autolink(link, link_type)
      link, stray = split_invalid_tail(link)
      html = case link_type
      when :url
        link(link, nil, link)
      when :email
        # NOTE: As of Redcarpet 3.6.0, autolinking email containing underscore is broken https://github.com/vmg/redcarpet/issues/402
        content_tag(:a, link, { href: "mailto:#{link}" })
      else
        link
      end
      stray ? html.to_str + stray : html
    end

    private

    def split_invalid_tail(text)
      return [text, nil] if text.valid_encoding?

      valid = text.dup
      valid = valid.byteslice(0, valid.bytesize - 1) until valid.valid_encoding?
      [valid, text.byteslice(valid.bytesize..)]
    end
  end
end
