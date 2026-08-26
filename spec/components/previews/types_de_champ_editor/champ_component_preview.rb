# frozen_string_literal: true

class TypesDeChampEditor::ChampComponentPreview < ViewComponent::Preview
  include Logic

  def nominal
    tdc = TypesDeChamp::Text.new(stable_id: 123)
    procedure = Procedure.new(id: 123)
    coordinate = ProcedureRevisionTypeDeChamp.new(type_de_champ: tdc, procedure:)
    upper_coordinates = []
    errors = 'une grosse erreur'

    render_with_template(locals: {
      coordinate:,
      upper_coordinates:,
      errors:,
    })
  end
end
