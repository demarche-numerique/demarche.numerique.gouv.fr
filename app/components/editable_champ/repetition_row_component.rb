# frozen_string_literal: true

class EditableChamp::RepetitionRowComponent < ApplicationComponent
  include ChampAriaLabelledbyHelper

  def initialize(form:, row:, expanded: false, seen_at: nil)
    @form, @row, @expanded, @seen_at = form, row, expanded, seen_at
    @champ = row.repetition
  end

  def row_id = @row.id
  def row_number = @row.index

  def has_fieldset?
    @row.flat_children.size > 1
  end

  private

  def section_component
    EditableChamp::SectionComponent.new(champs: @row.children, row_number:)
  end

  def delete_button
    render NestedForms::OwnedButtonComponent.new(
      formaction: champs_repetition_path(@champ.dossier, @champ.stable_id, row_id:),
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
