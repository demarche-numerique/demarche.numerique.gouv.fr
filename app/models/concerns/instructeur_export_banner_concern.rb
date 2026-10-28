# frozen_string_literal: true

module InstructeurExportBannerConcern
  extend ActiveSupport::Concern

  included do
    belongs_to :last_requested_export, class_name: 'Export', optional: true
  end

  def export_for_banner(pro_connect:)
    groupe_instructeurs = banner_groupe_instructeurs(pro_connect:)

    own_export_for_banner(groupe_instructeurs) || colleague_export_for_banner(groupe_instructeurs)
  end

  def request_export!(export)
    update!(last_requested_export_id: export.id, last_requested_export_dismissed_at: nil)
  end

  def dismiss_export_banner!(export_id)
    if export_id == last_requested_export_id
      update!(last_requested_export_dismissed_at: Time.current)
    else
      update!(colleague_exports_dismissed_at: Time.current)
    end
  end

  private

  def banner_groupe_instructeurs(pro_connect:)
    assignments = assign_to.where(manager: [false, nil])

    if !pro_connect
      unrestricted_procedures = Procedure.with_discarded.pro_connect_restriction_none
      assignments = assignments.where(groupe_instructeur: GroupeInstructeur.where(procedure: unrestricted_procedures))
    end

    assignments.select(:groupe_instructeur_id)
  end

  def own_export_for_banner(groupe_instructeurs)
    return if last_requested_export_id.nil?

    export = Export.for_groupe_instructeurs(groupe_instructeurs).find_by(id: last_requested_export_id)

    if export && (last_requested_export_dismissed_at.nil? || (export.available? && export.updated_at > last_requested_export_dismissed_at))
      export
    end
  end

  def colleague_export_for_banner(groupe_instructeurs)
    exports = Export.generated
      .where(user_profile_type: 'Instructeur')
      .where.not(user_profile_id: id)
      .for_groupe_instructeurs(groupe_instructeurs)

    if colleague_exports_dismissed_at
      exports = exports.where(Export.arel_table[:updated_at].gt(colleague_exports_dismissed_at))
    end

    export = exports.ante_chronological.first

    if export&.available?
      export
    end
  end
end
