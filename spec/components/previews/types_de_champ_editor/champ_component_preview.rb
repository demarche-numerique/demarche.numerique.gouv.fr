# frozen_string_literal: true

class TypesDeChampEditor::ChampComponentPreview < ViewComponent::Preview
  def nominal
    # the first type de champ a draft lays out: a card needs to know where it sits
    type_de_champ = Procedure.order(:id).lazy.filter_map { it.draft_revision&.type_de_champs&.first }.first

    render_with_template(locals: { type_de_champ:, errors: 'une grosse erreur' })
  end
end
