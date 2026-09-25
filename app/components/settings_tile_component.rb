# frozen_string_literal: true

# A tile of the procedure and groupe gestionnaire settings pages: status badge,
# optional counter, title, subtitle and action label, the whole tile being a link.
# It is not the standard DSFR tile (fr-tile__title, fr-tile__desc): see
# instructeurs/dossiers/_instruction_tiles for that one. The title and the action
# are slots so a caller can decorate them (a notification dot, a different label).
class SettingsTileComponent < ApplicationComponent
  BADGE_VARIANTS = [:success, :info, :warning, :error].freeze

  renders_one :title
  renders_one :action

  def initialize(url:, badge:, counter: nil, subtitle: nil, heading_level: :h3, link_attributes: {})
    @url = url
    @badge = badge
    @counter = counter
    @subtitle = subtitle
    @heading_level = heading_level
    @link_attributes = link_attributes
  end

  private

  def badge_class
    variant = @badge[:variant]
    raise ArgumentError, "unknown badge variant: #{variant}" if variant && BADGE_VARIANTS.exclude?(variant)

    class_names('fr-badge', "fr-badge--#{variant}" => variant, 'fr-badge--no-icon' => @badge[:icon] == false)
  end

  def counter?
    !@counter.nil?
  end
end
