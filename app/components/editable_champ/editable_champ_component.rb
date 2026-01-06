# frozen_string_literal: true

class EditableChamp::EditableChampComponent < ApplicationComponent
  include ChampAriaLabelledbyHelper

  def initialize(form:, champ:, seen_at: nil, row_number: nil)
    @form, @champ, @seen_at, @row_number = form, champ, seen_at, row_number
    @attribute = :value
  end

  def champ_component
    @champ_component ||= component_class.new(form: @form, champ: @champ, seen_at: @seen_at, aria_labelledby_prefix: aria_labelledby_prefix, row_number: row_number_if_in_repetition)
  end

  def parent_fieldset_legend_id
    "#{@champ.parent.html_id}-legend"
  end

  def fieldset_legend_id
    "#{@champ.parent.html_id(@champ.row_id)}-legend"
  end

  def aria_labelledby_prefix
    return "" if !number_of_siblings_if_in_repetition

    number_of_siblings_if_in_repetition > 1 ? fieldset_legend_id : parent_fieldset_legend_id
  end

  def number_of_siblings_if_in_repetition
    return if !@champ.child?

    @number_of_siblings_if_in_repetition ||= @champ.dossier.revision.children_of(@champ.parent).count
  end

  def row_number_if_in_repetition
    return if !@champ.child? || number_of_siblings_if_in_repetition > 1

    @row_number_if_in_repetition ||= begin
      parent = @champ.parent
      row_ids = @champ.dossier.repetition_row_ids(parent)
      row_ids.find_index(@champ.row_id)&.+ 1
    end
  end

  private

  def has_label?(champ)
    types_without_label = [
      TypeDeChamp.type_champs.fetch(:header_section),
      TypeDeChamp.type_champs.fetch(:explication),
      TypeDeChamp.type_champs.fetch(:repetition),
      TypeDeChamp.type_champs.fetch(:linked_drop_down_list),
      TypeDeChamp.type_champs.fetch(:quotient_familial),
    ]
    !types_without_label.include?(@champ.type_champ)
  end

  def component_class
    "EditableChamp::#{@champ.type_champ.camelcase}Component".constantize
  end

  def html_options
    {
      class: class_names(
        {
          'editable-champ': true,
          "editable-champ-#{@champ.type_champ}": true,
          champ_component.dsfr_group_classname => true,
        }.merge(champ_component.input_group_error_class_names)
      ),
      data: { controller: stimulus_controller, **data_dependent_conditions, **stimulus_values },
    }
      .deep_merge(champ_component.fieldset_aria_opts)
      .deep_merge(champ_component.fieldset_error_opts)
  end

  def fieldset_element_attributes
    {
      id: @champ.input_group_id,
      "hidden": !@champ.visible?,
    }
  end

  def stimulus_values
    if @champ.pending?
      {
        turbo_poll_url_value:,
        turbo_poll_interval_value: 2_000,
        turbo_poll_strategy_value: 'fixed',
      }
    else
      {}
    end
  end

  def turbo_poll_url_value
    if @champ.private?
      annotation_instructeur_dossier_path(@champ.dossier.procedure, @champ.dossier, @champ.stable_id, row_id: @champ.row_id)
    else
      champ_dossier_path(@champ.dossier, @champ.stable_id, row_id: @champ.row_id)
    end
  end

  def stimulus_controller
    if autosave_enabled?
      # This is an editable champ. Lets find what controllers it might need.
      controllers = ['autosave']

      if @champ.pending?
        controllers << 'turbo-poll'
      end

      controllers.join(' ')
    end
  end

  def data_dependent_conditions
    if @champ.dependent_conditions?
      { "dependent-conditions": "true" }
    else
      {}
    end
  end

  def autosave_enabled?
    !@champ.carte? && !@champ.repetition? && @champ.fillable?
  end
end
