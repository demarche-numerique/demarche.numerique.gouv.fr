# frozen_string_literal: true

module Administrateurs
  class APITokenTransfersController < AdministrateurController
    before_action :set_owned_api_token, only: [:new, :create, :destroy]
    before_action :ensure_transferable, only: [:new, :create]
    before_action :set_offered_api_token, only: [:show, :accept, :decline]

    def new
      set_coverage
    end

    def create
      recipient = Administrateur.find_by(id: params[:recipient_id])

      if recipient.present? && @api_token.offer_transfer!(recipient, by: current_administrateur)
        APITokenMailer.transfer_offered(@api_token, recipient).deliver_later
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
        redirect_no_longer_pending
      end
    end

    def show
      redirect_no_longer_pending if !@api_token.transferable?
    end

    def accept
      former_owner = @api_token.administrateur

      case @api_token.accept_transfer!(by: current_administrateur, fingerprint: params[:fingerprint])
      in :accepted
        APITokenMailer.transfer_accepted(api_token_name: @api_token.name, former_owner_email: former_owner.email, new_owner_email: current_administrateur.email).deliver_later
        redirect_to profil_path, notice: t('.accepted', name: ERB::Util.html_escape(@api_token.name))
      in :changed
        flash.now.alert = t('.changed')
        render :show, status: :unprocessable_content
      in :ineligible
        flash.now.alert = t('.ineligible')
        render :show, status: :unprocessable_content
      in :withdrawn
        redirect_no_longer_pending
      end
    end

    def decline
      if @api_token.decline_transfer!(by: current_administrateur)
        APITokenMailer.transfer_declined(api_token_name: @api_token.name, owner_email: @api_token.administrateur.email, recipient_email: current_administrateur.email).deliver_later
        redirect_to profil_path, notice: t('.declined')
      else
        redirect_no_longer_pending
      end
    end

    private

    def set_owned_api_token
      @api_token = current_administrateur.api_tokens.find(params[:api_token_id])
    end

    def set_offered_api_token
      @api_token = current_administrateur.offered_api_tokens.find_by(id: params[:api_token_id])
      redirect_no_longer_pending if @api_token.nil?
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

    def redirect_no_longer_pending
      redirect_to profil_path, alert: t('administrateurs.api_token_transfers.no_longer_pending')
    end
  end
end
