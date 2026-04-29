# frozen_string_literal: true

module Users
  class TransfersController < UserController
    def create
      dossier = current_user.dossiers.find(params[:id])
      email = params.require(:dossier_transfer).permit(:email)[:email]
      transfer = DossierTransfer.new(email:, dossiers: [dossier])

      if transfer.valid?
        transfer.save!
        flash.notice = t("users.dossiers.transferer.notice_sent")
        redirect_to dossiers_path
      else
        flash.alert = transfer.errors.full_messages
        redirect_to transferer_dossier_path(dossier)
      end
    end

    def update
      if DossierTransfer.accept(params[:id], current_user)
        flash.notice = t("users.dossiers.transferer.accepted")
      else
        flash.alert = t("users.dossiers.transferer.unauthorized_destroy")
      end
      redirect_to dossiers_path
    end

    def destroy
      transfer = DossierTransfer.find(params[:id])
      authorized = (transfer.email == current_user.email || transfer.dossiers.exists?(dossiers: { user: current_user }))

      if authorized
        transfer.destroy_and_nullify
        flash.notice = t("users.dossiers.transferer.destroy")
      else
        flash.alert = t("users.dossiers.transferer.unauthorized_destroy")
      end
      redirect_to dossiers_path
    end

    private
  end
end
