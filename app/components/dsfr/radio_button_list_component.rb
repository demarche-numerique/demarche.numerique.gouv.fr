# frozen_string_literal: true

class Dsfr::RadioButtonListComponent < ApplicationComponent
  attr_reader :error

  def initialize(form:, target:, buttons:, error: nil, inline: false, regular_legend: true)
    @form = form
    @target = target
    @buttons = buttons
    @error = error
    @inline = inline
    @regular_legend = regular_legend
  end

  def error?
    # TODO: mettre correctement le aria-labelled-by avec l’id du div qui contient les erreurs
    # https://www.systeme-de-design.gouv.fr/elements-d-interface/composants/bouton-radio/
    @error.present?
  end

  def each_button
    @buttons.each.with_index do |button, index|
      yield(*button.values_at(:label, :value, :hint, :tooltip), **button.merge!(index:).except(:label, :value, :hint, :tooltip))
    end
  end

  def label_options(button_options)
    {
      for: button_options[:id],
    }.compact
  end
end
