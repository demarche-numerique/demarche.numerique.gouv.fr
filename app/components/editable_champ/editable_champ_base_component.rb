# frozen_string_literal: true

class EditableChamp::EditableChampBaseComponent < ApplicationComponent
  include Dsfr::InputErrorable
  include ChampAriaLabelledbyHelper

  attr_reader :attribute
  attr_reader :aria_labelledby_prefix
  attr_reader :row_number

  def initialize(form:, champ:, seen_at: nil, opts: {}, aria_labelledby_prefix: nil, row_number: nil)
    @form, @champ, @seen_at, @opts, @aria_labelledby_prefix, @row_number = form, champ, seen_at, opts, aria_labelledby_prefix, row_number
    @attribute = :value
  end

  def dsfr_champ_container
    :div
  end

  def dsfr_input_classname
    nil
  end

  def describedby_id
    @champ.describedby_id
  end

  def labelledby_id_attr(label_id = nil)
    return {} if !@champ.in_repetition?

    { labelledby: labelledby_id(label_id) }
  end

  def fieldset_aria_opts
    if dsfr_champ_container == :fieldset
      labelledby = [input_label_id(@champ)]
      labelledby << describedby_id if @champ.description.present?

      {
        aria: { labelledby: labelledby.join(' ') },
        role: 'group',
      }
    else
      {}
    end
  end

  private

  def labelledby_id(label_id = nil)
    return nil if !@champ.in_repetition?

    labelledby = []
    # in repetition, aria_labelledby_prefix is the fieldset legend id
    labelledby << @aria_labelledby_prefix if @aria_labelledby_prefix.present?
    # in a type de champ with a fieldset (ex: address), we add the fieldset legend id of the type de champ
    labelledby << champ_fieldset_legend_id(@champ) if dsfr_champ_container == :fieldset
    # we add the label id of the input
    labelledby << (label_id.presence || input_label_id(@champ))

    labelledby.join(' ')
  end
end
