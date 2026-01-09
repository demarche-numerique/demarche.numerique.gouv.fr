# frozen_string_literal: true

module Manager
  class InstructeursController < Manager::ApplicationController
    def reinvite
      instructeur = Instructeur.find(params[:id])
      instructeur.user.invite_instructeur!
      flash[:notice] = "Instructeur réinvité."
      redirect_to manager_instructeur_path(instructeur)
    end

    def delete
      instructeur = Instructeur.find(params[:id])

      if !instructeur.can_be_deleted?
        fail "Impossible de supprimer cet instructeur car il est administrateur ou il est le seul instructeur sur une démarche"
      end
      instructeur.destroy!

      logger.info("L’instructeur #{instructeur.id} est supprimé par #{current_super_admin.id}")
      flash[:notice] = "L’instructeur #{instructeur.id} est supprimé"

      redirect_to manager_instructeurs_path
    end

    def export_last_half_year
      instructeurs = Instructeur.joins(:user).where(created_at: 6.months.ago..).where.not(users: { email_verified_at: nil })

      csv = generate_csv(instructeurs)

      send_data csv, filename: "instructeurs_recents_#{Date.today.strftime('%d-%m-%Y')}.csv"
    end

    def export_currently_active
      instructeurs = Instructeur.joins(:user).where(users: { current_sign_in_at: 6.months.ago.. }).where.not(users: { email_verified_at: nil })

      csv = generate_csv(instructeurs)

      send_data csv, filename: "instructeurs_actifs_#{Date.today.strftime('%d-%m-%Y')}.csv"
    end
  end
end
