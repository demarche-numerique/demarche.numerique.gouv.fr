# frozen_string_literal: true

module Redcarpet
  class TrustedRenderer < Redcarpet::Render::HTML
    include ActionView::Helpers::TagHelper
    include Sprockets::Rails::Helper
    include ApplicationHelper

    attr_reader :view_context

    def initialize(view_context, extensions = {})
      @view_context = view_context

      super extensions
    end

    def link(href, title, content)
      html_options = {
        href: href,
      }

      unless href.starts_with?('/')
        html_options.merge!(title: new_tab_suffix(content), **external_link_attributes)
      end

      content_tag(:a, content, html_options, false)
    end

    def autolink(link, link_type)
      case link_type
      when :url
        link(link, nil, link)
      when :email
        # NOTE: As of Redcarpet 3.6.0, autolinking email containing underscore is broken https://github.com/vmg/redcarpet/issues/402
        content_tag(:a, link, { href: "mailto:#{link}" })
      end
    end

    def image(link, title, alt_text)
      # Extrait les attributs personnalisés s’ils existent sous la forme { aria-hidden=true } dans les []
      custom_attributes = {}
      if alt_text =~ /\s*\{(.+)\}$/
        attr_string = Regexp.last_match(1)
        alt_text = alt_text.sub(/\s*\{.+\}$/, '').strip
        attr_string.split(' ').each do |attr|
          key, value = attr.split('=')
          custom_attributes[key.strip] = value.strip.delete('"')
        end
      end

      # Combine les attributs standard et personnalisés
      image_options = {
        alt: alt_text,
        title:,
        loading: :lazy,
      }.merge(custom_attributes)

      view_context.image_tag(link, image_options)
    end

    # rubocop:disable Rails/OutputSafety
    def block_quote(raw_html)
      if raw_html =~ /^<p>\[!(INFO|WARNING)\]\n/
        state = Regexp.last_match(1).downcase.to_sym
        content = raw_html.sub(/^<p>\[!(?:INFO|WARNING)\]\n/, '<p>')
        component = Dsfr::AlertComponent.new(state:, heading_level: "h2", extra_class_names: "fr-my-3w")
        component.render_in(view_context) do |c|
          c.with_body { content.html_safe }
        end
      else
        view_context.content_tag(:blockquote, raw_html.html_safe)
      end
    end
    # rubocop:enable Rails/OutputSafety
  end
end
