# frozen_string_literal: true

class TypesDeChampEditor::AddChampButtonComponent < ApplicationComponent
  def initialize(revision:, parent: nil, is_annotation: false, after_stable_id: nil)
    @revision = revision
    @parent = parent
    @is_annotation = is_annotation
    @after_stable_id = after_stable_id
  end

  private

  def annotations?
    @is_annotation
  end

  def procedure
    @revision.procedure
  end

  def button_title
    if annotations?
      "Ajouter une annotation"
    else
      "Ajouter un champ"
    end
  end

  def button_options
    {
      class: "fr-btn fr-btn--secondary fr-btn--icon-left fr-icon-add-line",
      method: :post,
      params: {
        type_de_champ: {
          libelle: champ_libelle,
          type: TypesDeChamp::Text.name,
          private: annotations? ? true : nil,
          parent_stable_id: @parent&.stable_id,
          after_stable_id: @after_stable_id,
        }.compact,
      },
    }
  end

  def champ_libelle
    if annotations?
      "Nouvelle annotation"
    else
      nil
    end
  end
end
