# frozen_string_literal: true

class EditableChamp::PieceJustificativeComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_input_classname
    'fr-input'
  end

  def view_as
    if @champ.dossier.brouillon?
      :link
    else
      :download
    end
  end

  def max
    if @champ.RIB? || @champ.titre_identite_nature?
      1
    elsif [true, nil].include?(@champ.procedure&.piece_justificative_multiple?)
      Attachment::FileFieldComponent::DEFAULT_MAX_ATTACHMENTS
    else
      1
    end
  end

  def attachment_context
    Attachment::Context.new(
      champ: @champ,
      view_as:,
      form_object_name: @form.object_name,
      aria_labelledby: labelledby_id
    )
  end
end
