# frozen_string_literal: true

module Manager
  class ProceduresController < Manager::ApplicationController
    include RequiresFreshSuperAdminOtp

    before_action :verify_fresh_super_admin_otp!, only: [:add_administrateur_and_instructeur]

    #
    # Administrate overrides
    #

    # Override this if you have certain roles that require a subset
    # this will be used to set the records shown on the `index` action.
    def scoped_resource
      if unfiltered_list?
        # Don't display discarded demarches in the unfiltered list…
        Procedure.kept
      else
        # … but allow them to be searched and displayed.
        Procedure.with_discarded
      end
    end

    def whitelist
      procedure.whitelist!
      flash[:notice] = "Démarche whitelistée."
      redirect_to manager_procedure_path(procedure)
    end

    def hide_as_template
      procedure.hide_as_template!
      flash[:notice] = "Démarche non visible dans les modèles."
      redirect_to manager_procedure_path(procedure)
    end

    def unhide_as_template
      procedure.unhide_as_template!
      flash[:notice] = "Démarche visible dans les modèles."
      redirect_to manager_procedure_path(procedure)
    end

    def discard
      procedure.discard_and_keep_track!(current_super_admin)

      logger.info("La démarche #{procedure.id} est supprimée par #{current_super_admin.email}")
      flash[:notice] = "La démarche #{procedure.id} a été supprimée."

      redirect_to manager_procedure_path(procedure)
    end

    def restore
      procedure.restore(current_super_admin)

      flash[:notice] = "La démarche #{procedure.id} a été restauré."

      redirect_to manager_procedure_path(procedure)
    end

    def export_mail_brouillons
      dossiers = procedure.dossiers.state_brouillon.visible_by_user.includes(:user)
      emails = dossiers.map { |dossier| dossier.user_email_for(:display) }.sort.uniq
      date = Time.zone.now.strftime('%d-%m-%Y')
      send_data(emails.join("\n"), :filename => "brouillons-#{procedure.id}-au-#{date}.csv")
    end

    def add_administrateur_and_instructeur_edit
      @procedure = procedure
    end

    def add_administrateur_and_instructeur
      administrateur = Administrateur.by_email(current_super_admin.email)
      instructeur = Instructeur.by_email(current_super_admin.email)
      notices, alerts = [], []

      if administrateur
        if !AdministrateursProcedure.exists?(procedure: procedure, administrateur: administrateur)
          AdministrateursProcedure.create!(procedure: procedure, administrateur: administrateur, manager: true)
        end
        notices.push "L’administrateur #{administrateur.email} a été ajouté à la démarche."
      else
        alerts.push "L’administrateur #{administrateur.email} est introuvable."
      end

      if instructeur
        procedure.groupe_instructeurs.map do |groupe_instructeur|
          if !instructeur.assign_to.exists?(groupe_instructeur: groupe_instructeur)
            instructeur.assign_to.create(groupe_instructeur: groupe_instructeur, manager: true)
          end
        end
        if procedure.groupe_instructeurs.many?
          notices.push "L’instructeur #{instructeur.email} a été ajouté aux #{procedure.groupe_instructeurs.count} groupes d’instructeurs."
        else
          notices.push "L’instructeur #{instructeur.email} a été ajouté à la démarche."
        end
      else
        alerts.push "L’instructeur #{instructeur.email} est introuvable."
      end

      flash[:notice] = notices.join(" ") if notices.present?
      flash[:alert] = alerts.join(" ") if alerts.present?

      redirect_to manager_procedure_path(procedure)
    end

    def add_administrateur_with_confirmation
      redirect_to new_manager_procedure_confirmation_url_path(procedure, email: params[:email])
    end

    def delete_administrateur
      administrateur = procedure.administrateurs.find { |admin| admin.email == current_super_admin.email }
      if administrateur.present?
        procedure.administrateurs.delete(administrateur)
      end

      instructeur = Instructeur.by_email(current_super_admin.email)
      if instructeur.present?
        procedure.groupe_instructeurs.map do |groupe_instructeur|
          groupe_instructeur.assign_tos.where(instructeur: instructeur).destroy_all
        end
      end

      redirect_to manager_procedure_path(procedure)
    end

    def change_piece_justificative_template
      if type_de_champ.update(type_de_champ_params)
        flash[:notice] = "Le modèle est mis à jour."
      else
        flash[:alert] = type_de_champ.errors.full_messages.join(', ')
      end
      redirect_to manager_procedure_path(procedure)
    end

    def update_template_status
      if procedure.update(template_params)
        redirect_to manager_procedure_path(procedure), notice: 'Le statut de modèle a été mis à jour.'
      else
        flash.alert = procedure.errors.full_messages.join(', ')
      end
    end

    private

    def find_resource(param)
      procedure = super

      procedure.preload_draft_and_published_revisions

      procedure
    end

    def procedure
      @procedure ||= Procedure.with_discarded.find(params[:id])
    end

    def type_de_champ
      procedure.draft_revision.revision_type_de_champs.find_by!(type_de_champ_id: params[:type_de_champ][:id]).type_de_champ
    end

    def type_de_champ_params
      params.require(:type_de_champ).permit(:piece_justificative_template)
    end

    def template_params
      params.require(:procedure).permit(:template)
    end

    def unfiltered_list?
      action_name == "index" && !params[:search]
    end
  end
end
