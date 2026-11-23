# frozen_string_literal: true

module Manager
  class AdministrateursController < Manager::ApplicationController
    include RequiresFreshSuperAdminOtp

    MERGE_PURPOSE = :confirm_merging_administrateur
    MERGE_LINK_VALIDITY = 1.day

    # Like adding an administrateur to a procedure, the merge link generated
    # by a super admin must be confirmed by another one.
    before_action :decrypt_merge_params, only: [:merge_link, :merge_edit, :merge]
    before_action :ensure_other_super_admin, only: [:merge_edit, :merge], unless: -> { Rails.env.development? }
    # After the link checks, so that an invalid link does not use up an OTP attempt.
    before_action :verify_fresh_super_admin_otp!, only: [:delete, :request_merge, :merge]

    def new
      from = AdministrateurCreationRequest.find_by(id: params[:from], requester: current_super_admin)
      @creation_request = AdministrateurCreationRequest.new(emails: from&.emails || [])
    end

    def create
      @creation_request = AdministrateurCreationRequest.new(
        requester: current_super_admin,
        emails: AdministrateurCreationRequest.parse_emails(params[:emails])
      )
      return render :new, status: :unprocessable_content if @creation_request.invalid?

      if @creation_request.emails.many?
        verify_fresh_super_admin_otp!
        return if performed?

        @creation_request.otp_verified = SUPER_ADMIN_OTP_ENABLED
      end

      @creation_request.update!(state: @creation_request.requires_validation? ? :pending : :approved)

      if @creation_request.pending?
        redirect_to manager_administrateur_creation_request_path(@creation_request)
      else
        @creation_request.create_accounts!
        redirect_to manager_administrateurs_path, notice: @creation_request.results_summary
      end
    end

    def reinvite
      Administrateur.find_inactive_by_id(params[:id]).user.invite_administrateur!
      flash.notice = "Invitation renvoyée"
      redirect_to manager_administrateur_path(params[:id])
    end

    def delete_edit
      @administrateur = Administrateur.find(params[:id])
    end

    def delete
      administrateur = Administrateur.find(params[:id])

      result = AdministrateurDeletionService.new(current_super_admin, administrateur).call

      case result
      in Dry::Monads::Result::Success
        logger.info("L’administrateur #{administrateur.id} est supprimé par #{current_super_admin.id}")
        flash[:notice] = "L’administrateur #{administrateur.id} est supprimé"
      in Dry::Monads::Result::Failure(reason)
        flash[:alert] = t(reason, scope: "manager.administrateurs.delete")
      end

      redirect_to manager_administrateurs_path
    end

    def request_merge
      @old_administrateur = Administrateur.by_email(params[:email].to_s.strip.downcase)

      if @old_administrateur.nil?
        return redirect_to_administrateur(:alert, "Aucun administrateur n’a l’adresse « #{params[:email]} ».")
      end

      redirect_to merge_link_manager_administrateur_path(requested_resource, q: encrypted_merge_params)
    end

    def merge_link
      @administrateur = requested_resource
      @url = merge_edit_manager_administrateur_url(@administrateur, q: params[:q])
    end

    def merge_edit
      @administrateur = requested_resource
      @inviter = SuperAdmin.find(@inviter_id)
    end

    def merge
      requested_resource.take_over(@old_administrateur)
      logger.info("L’administrateur #{@old_administrateur.id} a été fusionné dans #{requested_resource.id} par #{current_super_admin.id}, sur invitation de #{@inviter_id}")

      redirect_to_administrateur(:notice, "L’administrateur « #{requested_resource.email} » a récupéré les démarches, services, instructeurs et jetons d’API de « #{@old_administrateur.email} ».")
    end

    def data_exports
    end

    def export_last_half_year
      administrateurs = Administrateur.joins(:user).where(created_at: 6.months.ago..).where.not(users: { email_verified_at: nil })

      csv = generate_csv(administrateurs)

      send_data csv, filename: "administrateurs_recents_#{Date.today.strftime('%d-%m-%Y')}.csv"
    end

    def export_with_publiee_procedure
      administrateurs = Administrateur.joins(:user).where.not(users: { email_verified_at: nil }).joins(:procedures).where(procedures: { aasm_state: [:publiee] })

      csv = generate_csv(administrateurs)

      send_data csv, filename: "administrateurs_actifs_#{Date.today.strftime('%d-%m-%Y')}.csv"
    end

    private

    def encrypted_merge_params
      payload = { administrateur_id: requested_resource.id, old_administrateur_id: @old_administrateur.id, inviter_id: current_super_admin.id }
      message_encryptor_service.encrypt_and_sign(payload, purpose: MERGE_PURPOSE, expires_in: MERGE_LINK_VALIDITY)
    end

    def decrypt_merge_params
      payload = message_encryptor_service.decrypt_and_verify(params[:q], purpose: MERGE_PURPOSE)&.symbolize_keys rescue nil

      @inviter_id = payload&.dig(:inviter_id)
      @old_administrateur = Administrateur.find_by(id: payload&.dig(:old_administrateur_id))

      if @old_administrateur.nil? || payload[:administrateur_id] != requested_resource.id
        redirect_to_administrateur(:error, "Le lien que vous avez utilisé est invalide. Veuillez contacter la personne qui vous l’a envoyé.")
      end
    end

    def ensure_other_super_admin
      if @inviter_id == current_super_admin.id || requested_resource.email == current_super_admin.email
        redirect_to_administrateur(:alert, "Veuillez partager ce lien avec un autre super administrateur pour qu’il confirme votre action")
      end
    end

    def redirect_to_administrateur(type, message)
      flash[type] = message
      redirect_to manager_administrateur_path(requested_resource)
    end
  end
end
