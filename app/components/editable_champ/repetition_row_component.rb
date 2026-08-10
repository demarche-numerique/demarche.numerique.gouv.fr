# frozen_string_literal: true

class EditableChamp::RepetitionRowComponent < ApplicationComponent
  include ChampAriaLabelledbyHelper

  def initialize(champ:, row:, expanded: false)
    @champ, @row, @expanded = champ, row, expanded
    @type_de_champ = champ.type_de_champ
  end

  def row_id = @row.id
  def row_number = @row.index

  def has_fieldset?
    @type_de_champ.flat_children.size > 1
  end

  private

  def dossier = @champ.dossier

  def section_component
    EditableChamp::SectionComponent.new(dossier:, champs: @row.champs, row_number:)
  end

  def delete_button
    render NestedForms::OwnedButtonComponent.new(
      formaction: champs_repetition_path(dossier, @type_de_champ.stable_id, row_id:),
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
