# frozen_string_literal: true

# see: https://www.systeme-de-design.gouv.fr/elements-d-interface/composants/alerte
class Dsfr::AlertComponent < ApplicationComponent
  renders_one :body

  attr_reader :state, :title, :size, :block, :extra_class_names, :heading_level

  def initialize(state:, title: '', size: '', extra_class_names: nil, heading_level: 'h3')
    @state = state
    @title = title
    @size = size
    @block = block
    @extra_class_names = extra_class_names
    @heading_level = heading_level
  end

  def prefix_for_state
    case state
    when :error then "Erreur : "
    when :info then "Information : "
    when :warning then "Attention : "
    when :success then ""
    else ""
    end
  end

  def alert_class(state)
    class_names(
      "fr-alert" => true,
      "fr-alert--#{state}" => state.present?,
      "fr-alert--sm" => size == :sm,
      extra_class_names => true
    )
  end
end
