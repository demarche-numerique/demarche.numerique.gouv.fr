# frozen_string_literal: true

class TypesDeChampEditor::InfoReferentielComponent < ApplicationComponent
  attr_reader :procedure, :type_de_champ
  delegate :referentiel, to: :type_de_champ
  delegate :ready?, to: :referentiel, allow_nil: true

  def initialize(procedure:, type_de_champ:)
    @procedure = procedure
    @type_de_champ = type_de_champ
  end

  # Un référentiel partagé avec la révision publiée est dupliqué par le contrôleur
  # à la première modification : le lien mène toujours à l'édition.
  def configure_referentiel_url
    if referentiel.nil?
      new_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id)
    else
      edit_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel)
    end
  end
end
