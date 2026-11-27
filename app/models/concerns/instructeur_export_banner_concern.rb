# frozen_string_literal: true

module InstructeurExportBannerConcern
  extend ActiveSupport::Concern

  def export_for_banner(pro_connect:)
    groupe_instructeur_ids = banner_groupe_instructeur_ids(pro_connect:)
    return if groupe_instructeur_ids.empty?

    exports = Export.where(user_profile_type: 'Instructeur').for_groupe_instructeurs(groupe_instructeur_ids)
    pending = exports.pending.where(user_profile: self)
    completed = exports.generated.where(id: Export.joins(:file_attachment).select(:id))
      .or(exports.failed.where(user_profile: self))

    if export_banner_dismissed_at
      pending = pending.where(Export.arel_table[:created_at].gt(export_banner_dismissed_at))
      completed = completed.where(Export.arel_table[:updated_at].gt(export_banner_dismissed_at))
    end

    pending.includes(groupe_instructeurs: :procedure).order(created_at: :desc, id: :desc).first ||
      completed.with_attached_file.order(updated_at: :desc, id: :desc).first
  end

  def request_export!
    update!(export_banner_dismissed_at: nil)
  end

  def dismiss_export_banner!
    update!(export_banner_dismissed_at: Time.current)
  end

  private

  def banner_groupe_instructeur_ids(pro_connect:)
    procedures = pro_connect ? Procedure.all : Procedure.pro_connect_restriction_none

    assign_to
      .where(manager: [false, nil])
      .where(groupe_instructeur: GroupeInstructeur.where(procedure: procedures))
      .pluck(:groupe_instructeur_id)
  end
end
