# frozen_string_literal: true

class Dsfr::ToggleComponent < ApplicationComponent
  attr_reader :target
  attr_reader :title
  attr_reader :html_title
  attr_reader :hint
  attr_reader :toggle_labels
  attr_reader :disabled
  attr_reader :data
  attr_reader :extra_class_names

  def initialize(form:, target:, title: nil, html_title: nil, disabled: nil, checked: nil, hint: nil, toggle_labels: { checked: 'Activé', unchecked: 'Désactivé' }, opt: nil, extra_class_names: "fr-toggle--label-left")
    @form = form
    @target = target
    @title = title
    @html_title = html_title
    @hint = hint
    @disabled = disabled
    @checked = checked
    @toggle_labels = toggle_labels
    @data = opt
    @extra_class_names = extra_class_names
  end

  private

  def check_box_options
    opts = { class: 'fr-toggle__input', disabled: disabled }
    opts[:id] = input_id if @form.object.present?
    opts[:checked] = @checked unless @checked.nil?
    opts[:data] = @data if @data.present?
    opts
  end

  def label_options
    opts = { data: label_data, class: 'fr-toggle__label' }
    opts[:for] = input_id if @form.object.present?
    opts
  end

  def input_id
    dom_id(@form.object, target)
  end

  def label_data
    if toggle_labels
      {
        'fr-checked-label': toggle_labels[:checked],
        'fr-unchecked-label': toggle_labels[:unchecked],
        'fr-js-toggle-status-label': true,
      }
    else
      { 'fr-js-toggle-status-label': true }
    end
  end
end
