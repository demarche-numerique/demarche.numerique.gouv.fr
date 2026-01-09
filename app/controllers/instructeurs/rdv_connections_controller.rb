# frozen_string_literal: true

module Instructeurs
  class RdvConnectionsController < InstructeurController
    def show
      @rdv_email = RdvService.new(rdv_connection: current_instructeur.rdv_connection).get_account_info["email"]
    end

    def destroy
      current_instructeur.rdv_connection.destroy
      flash.notice = "Votre compte Démarches Simplifiées n’est plus connecté à RDV Service Public."
      redirect_to params[:redirect_path] || profil_path
    end
  end
end
