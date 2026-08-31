# frozen_string_literal: true

# The HTML print profile (config/pdf_profile.yml): the whitelist of what our
# document templates may send to the PDF renderer. Enforced on rendered output
# by spec/lint/pdf_profile_spec.rb, and at runtime by the scrubber applied to
# admin-authored attestation bodies (attestation_template_v2s/show).
module PdfProfile
  def self.profile
    @profile ||= YAML.safe_load_file(Rails.root.join('config/pdf_profile.yml'))
  end

  def self.admin_content_tags = profile.fetch('admin_content').fetch('elements')

  def self.admin_content_attributes = profile.fetch('admin_content').fetch('attributes')

  def self.inline_styles = profile.fetch('inline_styles')

  # Fresh instance per render: scrubbers carry per-document state.
  def self.admin_content_scrubber = AdminContentScrubber.new

  # PermitScrubber restricted to the profile's admin_content whitelist, with
  # two extras: <script>/<style> are pruned with their content (a bare
  # PermitScrubber would inline it as text), and style="" declarations are
  # filtered against the profile's inline_styles whitelist (Loofah's own CSS
  # safelist is much broader - it lets color, width etc. through).
  class AdminContentScrubber < Rails::HTML::PermitScrubber
    PRUNE = %w[script style].freeze

    def initialize
      super
      self.tags = PdfProfile.admin_content_tags
      self.attributes = PdfProfile.admin_content_attributes
    end

    def scrub_node(node)
      PRUNE.include?(node.name) ? node.remove : super
    end

    def scrub_attributes(node)
      super
      scrub_style(node) if node['style']
    end

    private

    def scrub_style(node)
      kept = node['style'].split(';').filter_map do |declaration|
        property, value = declaration.split(':', 2).map(&:strip)
        next if property.blank? || value.blank?

        "#{property}: #{value}" if PdfProfile.inline_styles[property]&.include?(value)
      end

      if kept.empty?
        node.remove_attribute('style')
      else
        node['style'] = kept.join('; ')
      end
    end
  end
end
