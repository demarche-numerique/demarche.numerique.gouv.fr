# frozen_string_literal: true

module Administrateurs
  class APITokenTransfersController < AdministrateurController
    before_action :set_owned_api_token, only: [:new, :create, :destroy]
    before_action :ensure_transferable, only: [:new, :create]

    def new
      set_coverage
    end

    def create
      recipient = Administrateur.find_by(id: params[:recipient_id])

      if recipient.present? && @api_token.offer_transfer!(recipient, by: current_administrateur)
        redirect_to edit_admin_api_token_path(@api_token), notice: t('.offered', email: recipient.email)
      else
        set_coverage
        @recipient_error = t('.choose_a_recipient')
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      if @api_token.cancel_transfer!(by: current_administrateur)
        redirect_to edit_admin_api_token_path(@api_token), notice: t('.cancelled')
      else
        redirect_to profil_path, alert: t('administrateurs.api_token_transfers.no_longer_pending')
      end
    end

    private

    def set_owned_api_token
      @api_token = current_administrateur.api_tokens.find(params[:api_token_id])
    end

    def ensure_transferable
      if !@api_token.transferable?
        redirect_to edit_admin_api_token_path(@api_token), alert: t('administrateurs.api_token_transfers.not_transferable')
      end
    end

    def set_coverage
      coverage = @api_token.transfer_coverage
      @eligible = coverage.filter { |_, missing| missing.zero? }.keys
      @not_covering = coverage.reject { |_, missing| missing.zero? }
    end
  end
end
