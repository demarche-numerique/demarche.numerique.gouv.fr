# frozen_string_literal: true

# We need to ensure the embed code is not any random string in order to avoid injections
class MonAvisEmbedValidator < ActiveModel::Validator
  DOMAIN_CHECKER = /\Ahttps:\/\/[a-z0-9-]+\.numerique\.gouv\.fr\//

  ALLOWED_TAGS = %w[a img].freeze
  ALLOWED_ATTRIBUTES = %w[href src alt title target rel].freeze
  ALLOWED_SCHEME = /\Ahttps:\/\//i

  def validate(record)
    return if record.monavis_embed.blank?
    fragment = parse_fragment(record)
    return unless fragment

    ensure_only_allowed_nodes!(record, fragment)

    check_link(record, fragment.css('a'))

    check_img(record, fragment.css('img'))
  end

  def check_link(record, links)
    return record.errors.add(:monavis_embed, :single_link_required) if links.size != 1

    href = links.first['href'].to_s.strip
    record.errors.add(:monavis_embed, :forbidden_scheme) unless allowed_scheme?(href)
    record.errors.add(:monavis_embed, :bad_domain_link) unless DOMAIN_CHECKER.match?(href)
  end

  def check_img(record, imgs)
    return record.errors.add(:monavis_embed, :single_image_required) if imgs.size != 1

    img = imgs.first
    src = img['src'].to_s.strip
    record.errors.add(:monavis_embed, :forbidden_scheme) unless allowed_scheme?(src)
    record.errors.add(:monavis_embed, :bad_domain_image) unless DOMAIN_CHECKER.match?(src)
  end

  private

  def parse_fragment(record)
    Nokogiri::HTML::DocumentFragment.parse(record.monavis_embed)
  rescue StandardError
    record.errors.add(:monavis_embed, :invalid_format)
    nil
  end

  def ensure_only_allowed_nodes!(record, fragment)
    fragment.traverse do |node|
      next unless node.element?

      record.errors.add(:monavis_embed, :forbidden_element, value: node.name) unless ALLOWED_TAGS.include?(node.name)

      node.attribute_nodes.each do |attr|
        name = attr.name.to_s
        record.errors.add(:monavis_embed, :forbidden_attribute, value: name) unless ALLOWED_ATTRIBUTES.include?(name)
      end
    end
  end

  def allowed_scheme?(value)
    v = value.to_s.strip
    !!(ALLOWED_SCHEME.match?(v))
  end
end
