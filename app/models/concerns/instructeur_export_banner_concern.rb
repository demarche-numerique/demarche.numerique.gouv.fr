# frozen_string_literal: true

module InstructeurExportBannerConcern
  extend ActiveSupport::Concern

  included do
    belongs_to :last_requested_export, class_name: 'Export', optional: true
  end

  def export_for_banner(pro_connect:)
    groupe_instructeur_ids = banner_groupe_instructeur_ids(pro_connect:)
    return if groupe_instructeur_ids.empty?

    own_export_for_banner(groupe_instructeur_ids) || colleague_export_for_banner(groupe_instructeur_ids)
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

  def banner_groupe_instructeur_ids(pro_connect:)
    assignments = assign_to.where(manager: [false, nil])

    if !pro_connect
      unrestricted_procedures = Procedure.with_discarded.pro_connect_restriction_none
      assignments = assignments.where(groupe_instructeur: GroupeInstructeur.where(procedure: unrestricted_procedures))
    end

    assignments.pluck(:groupe_instructeur_id)
  end

  def own_export_for_banner(groupe_instructeur_ids)
    return if last_requested_export_id.nil?

    export = Export.includes(:groupe_instructeurs).find_by(id: last_requested_export_id)
    return if export.nil? || !within_groupe_instructeurs?(export, groupe_instructeur_ids)

    if last_requested_export_dismissed_at.nil? || (export.available? && export.updated_at > last_requested_export_dismissed_at)
      export
    end
  end

  def within_groupe_instructeurs?(export, groupe_instructeur_ids)
    export_groupe_instructeur_ids = export.groupe_instructeurs.map(&:id)

    export_groupe_instructeur_ids.present? && (export_groupe_instructeur_ids - groupe_instructeur_ids).empty?
  end

  def colleague_export_for_banner(groupe_instructeur_ids)
    exports = Export.generated
      .where(user_profile_type: 'Instructeur')
      .where.not(user_profile_id: id)
      .for_groupe_instructeurs(groupe_instructeur_ids)

    if colleague_exports_dismissed_at
      exports = exports.where(Export.arel_table[:updated_at].gt(colleague_exports_dismissed_at))
    end

    export = exports.ante_chronological.first

    if export&.available?
      export
    end
  end
end
