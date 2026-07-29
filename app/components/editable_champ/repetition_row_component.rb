# frozen_string_literal: true

class EditableChamp::RepetitionRowComponent < ApplicationComponent
  include ChampAriaLabelledbyHelper

  def initialize(form:, dossier:, champ:, row_id:, row_number:, expanded: false, seen_at: nil)
    @form, @dossier, @champ, @row_id, @row_number, @expanded, @seen_at = form, dossier, champ, row_id, row_number, expanded, seen_at
    @type_de_champ = champ.type_de_champ
  end

  attr_reader :row_id, :row_number

  def has_fieldset?
    @type_de_champ.flat_children.size > 1
  end

  private

  def section_component
    champs = @type_de_champ.children.map { @dossier.project_champ(_1, row_id: @row_id) }
    EditableChamp::SectionComponent.new(champs:, row_number: @row_number)
  end

  def delete_button
    render NestedForms::OwnedButtonComponent.new(
      formaction: champs_repetition_path(@dossier, @type_de_champ.stable_id, row_id:),
      http_method: :delete,
      opt: {
        class: "fr-btn fr-btn--sm fr-btn--tertiary fr-icon-delete-bin-line fr-btn--icon-left utils-repetition-required-destroy-button",
        data: { turbo_confirm: t(".confirm", libelle: @champ.row_libelle, row_number:) },
      }
    ) do
      t(".delete", libelle: @champ.row_libelle, row_number:)
    end
  end
end
