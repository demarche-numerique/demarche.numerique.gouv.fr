# frozen_string_literal: true

module ProcedureSpecHelper
  def fill_in_dummy_procedure_details(fill_path: true)
    fill_in 'procedure_libelle', with: 'libelle de la procedure'
    fill_in 'procedure_description', with: "description de l’objet de la procedure"
    fill_in 'procedure_description_target_audience', with: "description d'à qui s’adresse la procedure"
    fill_in 'procedure_cadre_juridique', with: 'cadre juridique'
    fill_in 'procedure_duree_conservation_dossiers_dans_ds', with: '3'
  end
end
