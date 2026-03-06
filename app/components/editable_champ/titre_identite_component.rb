# frozen_string_literal: true

class EditableChamp::TitreIdentiteComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_input_classname
    'fr-input'
  end

  def hint_id
    "#{@champ.focusable_input_id}-pj-hint"
  end

  def max_file_size
    Champs::TitreIdentiteChamp::FILE_MAX_SIZE
  end

  def allowed_formats
    Champs::TitreIdentiteChamp::ACCEPTED_FORMATS
      .filter_map { |ct| MiniMime.lookup_by_content_type(ct)&.extension }
      .uniq
  end

  def attachment_context
    Attachment::Context.new(
      champ: @form.object,
      form_object_name: @form.object_name,
      aria_labelledby: labelledby_id,
      parent_hint_id: hint_id
    )
  end
end
