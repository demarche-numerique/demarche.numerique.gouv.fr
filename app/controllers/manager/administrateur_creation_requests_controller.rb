# frozen_string_literal: true

module Manager
  class AdministrateurCreationRequestsController < Manager::ApplicationController
    include RequiresFreshSuperAdminOtp

    before_action :set_creation_request
    helper_method :closed_message
    before_action :ensure_other_super_admin, only: [:approve, :refuse]
    before_action :ensure_requester, only: [:cancel]
    # After the checks above, so that a dead request does not use up an OTP attempt.
    before_action :ensure_pending, only: [:approve, :refuse, :cancel]
    before_action :verify_fresh_super_admin_otp!, only: [:approve]

    def show
    end

    def approve
      return redirect_to_request(:alert, closed_message) unless @creation_request.approve!(current_super_admin)

      AdministrateurCreationRequestJob.perform_later(@creation_request)
      flash[:notice] = t('.success', count: @creation_request.emails.size)
      redirect_to manager_administrateurs_path
    end

    def refuse
      return redirect_to_request(:alert, closed_message) unless @creation_request.refuse!(current_super_admin)

      redirect_to_request(:notice, t('.success'))
    end

    def cancel
      return redirect_to_request(:alert, closed_message) unless @creation_request.cancel!

      redirect_to new_manager_administrateur_path(from: (@creation_request.id if params[:edit])), notice: t('.success')
    end

    private

    def set_creation_request
      @creation_request = AdministrateurCreationRequest.find(params[:id])
    end

    def ensure_other_super_admin
      redirect_to_request(:alert, t('manager.administrateur_creation_requests.other_super_admin_required')) if @creation_request.requester_id == current_super_admin.id
    end

    def ensure_requester
      redirect_to_request(:alert, t('manager.administrateur_creation_requests.requester_only')) if @creation_request.requester_id != current_super_admin.id
    end

    def ensure_pending
      redirect_to_request(:alert, closed_message) if !@creation_request.open?
    end

    def closed_message
      t("manager.administrateur_creation_requests.closed.#{@creation_request.status}")
    end

    def redirect_to_request(type, message)
      flash[type] = message
      redirect_to manager_administrateur_creation_request_path(@creation_request)
    end
  end
end
