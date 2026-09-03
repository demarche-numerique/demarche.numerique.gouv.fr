# frozen_string_literal: true

class EditableChamp::DossierLinkComponent < EditableChamp::EditableChampBaseComponent
  THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE = 20

  def dsfr_input_classname
    limited? ? 'fr-select' : 'fr-input'
  end

  def limited?
    @champ.selectable?
  end

  def render_as_autocomplete?
    total_dossiers >= THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE
  end

  def grouped_select_options
    grouped_dossiers.map do |procedure, dossiers|
      options = if dossiers.empty?
        [[t('.no_dossier_in_procedure'), '', { disabled: true }]]
      else
        dossiers.map { |dossier| [option_label(dossier), dossier.id.to_s] }
      end

      [section_label(procedure), options]
    end
  end

  def select_react_props
    {
      class_name: 'fr-mt-1w',
      trigger_id: @champ.focusable_input_id,
      name: @form.field_name(:value),
      sections: select_sections,
      disabled_keys:,
      value: @champ.value.presence,
      placeholder: t('.select_placeholder'),
      is_required: @champ.required?,
      label_id: input_label_id(@champ),
      ariaLabelledbyPrefix: aria_labelledby_prefix,
      'aria-describedby': select_aria_describedby,
    }.compact
  end

  def select_class_names
    class_names('width-100': contains_long_option?, 'fr-select': true)
  end

  def select_aria_describedby
    describedby = []
    describedby << @champ.describedby_id if @champ.description.present?
    describedby << @champ.error_id(:value) if errors_on_attribute?
    describedby.presence&.join(' ')
  end

  private

  # A procedure without any dossier still gets a section, holding a single item explaining
  # why: its key is disabled so it can be read but never selected.
  def select_sections
    grouped_dossiers.map do |procedure, dossiers|
      items = if dossiers.empty?
        [{ label: t('.no_dossier_in_procedure'), value: empty_procedure_key(procedure) }]
      else
        dossiers.map { { label: option_label(it), value: it.id.to_s } }
      end

      { label: section_label(procedure), items: }
    end
  end

  def disabled_keys
    grouped_dossiers.filter_map { |procedure, dossiers| empty_procedure_key(procedure) if dossiers.empty? }
  end

  def empty_procedure_key(procedure) = "no-dossier-#{procedure.id}"

  def grouped_dossiers
    @champ.linkable_dossiers_by_procedure
  end

  def total_dossiers
    grouped_dossiers.sum { |_procedure, dossiers| dossiers.size }
  end

  def contains_long_option?
    @champ.linkable_procedures.any? { |procedure| procedure.libelle.size > 100 }
  end

  def section_label(procedure)
    t('.procedure_section', libelle: procedure.libelle)
  end

  def option_label(dossier)
    if dossier.expired?
      t('.option_expired', id: dossier.id, date: l(dossier.depose_on), expired_date: l(dossier.expired_on))
    else
      t('.option', id: dossier.id, date: l(dossier.depose_on))
    end
  end
end
