# frozen_string_literal: true

module ConservationDeDonneesHelper
  def politiques_conservation_de_donnees(procedure)
    [conservation_dans_ds(procedure)].compact
  end

  private

  def conservation_dans_ds(procedure)
    if procedure.duree_conservation_dossiers_dans_ds.present?
      t('users.procedure_footer.legals.data_retention',
             duree_conservation_dossiers_dans_ds: procedure.duree_conservation_dossiers_dans_ds)
    end
  end
end
