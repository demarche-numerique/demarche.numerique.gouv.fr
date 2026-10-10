# frozen_string_literal: true

class TypesDeChampEditor::ChampComponentPreview < ViewComponent::Preview
  include Logic

  def nominal
    tdc = TypeDeChamp.new(type_champ: 'text', stable_id: 123)
    procedure = Procedure.new(id: 123)
    coordinate = ProcedureRevisionTypeDeChamp.new(type_de_champ: tdc, procedure:)
    errors = 'une grosse erreur'

    render_with_template(locals: {
      coordinate:,
      errors:,
    })
  end
end
