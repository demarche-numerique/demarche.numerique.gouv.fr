# frozen_string_literal: true

module Maintenance
  class T20260911BackfillMissingGeoAreaUuidTask < MaintenanceTasks::Task
    # Documentation: cette tâche attribue un uuid aux zones géographiques qui
    # n'en ont pas. Jusqu'ici seules les zones créées sur le flux principal en
    # recevaient un : une zone dessinée lors d'une correction (flux tampon)
    # restait sans uuid après la fusion. Les copies d'une même zone dans les
    # autres flux reçoivent le même uuid.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      GeoArea.where(uuid: nil)
    end

    def process(geo_area)
      geo_area.reload
      return if geo_area.uuid.present?

      champ_data = geo_area.champ_data
      siblings = GeoArea.joins(:champ_data)
        .where(geometry: geo_area.geometry, champs: { dossier_id: champ_data.dossier_id, stable_id: champ_data.stable_id, row_id: champ_data.row_id })
      uuid = siblings.where.not(uuid: nil).pick(:uuid) || SecureRandom.uuid

      siblings.where(uuid: nil).update_all(uuid:)
    end

    def count
      # do not count, avoid timeout
    end
  end
end
