# frozen_string_literal: true

module Instructeurs
  class AvisController < InstructeurController
    before_action :authenticate_instructeur!
    A_DONNER_STATUS = 'a-donner'
    DONNES_STATUS   = 'donnes'

    def revoquer
      avis = Avis.find(params[:id])
      if avis.revoke_by!(current_instructeur)
        flash.notice = t('.revoked', email: avis.expert.email)
        DossierNotification.destroy_notifications_by_dossier_and_type(avis.dossier, :attente_avis) if avis.dossier.avis.without_answer.empty?

        redirect_back(fallback_location: avis_instructeur_dossier_path(avis.procedure, params[:statut], avis.dossier))
      end
    end

    def remind
      avis = Avis.find(params[:id])
      if avis.remind_by!(current_instructeur)
        avis.expert.user.invite_expert_and_send_avis!(avis)
        flash.notice = t('.reminded', email: avis.expert.email)
        redirect_back(fallback_location: avis_instructeur_dossier_path(avis.procedure, params[:statut], avis.dossier))
      end
    end
  end
end
