# frozen_string_literal: true

class APIController < ApplicationController
  before_action :default_format_json
  before_action :authenticate_from_token
  before_action :ensure_authorized_network, if: -> { @api_token.present? }
  before_action :ensure_token_is_not_expired, if: -> { @api_token.present? }

  before_action do
    Current.browser = 'api'
  end

  private

  def default_format_json
    request.format = "json" if !request.params[:format]
  end

  def check_api_token
    if @api_token.nil?
      render json: {}, status: :unauthorized
    end
  end

  def authenticate_from_token
    @api_token = authenticate_with_http_token { |t, _o| APIToken.authenticate(t) }

    # legacy way of sending the token by url
    # not available in api v2
    if @api_token.nil?
      @api_token = APIToken.authenticate(params[:token])
    end

    if @api_token.present?
      @api_token.touch(:last_v1_authenticated_at)
      @api_token.assign_first_ip!(request.remote_ip)
      @api_token.store_new_ip(request.remote_ip)
      @current_user = @api_token.administrateur.user
    end
  end

  def ensure_authorized_network
    if @api_token.forbidden_network?(request.remote_ip)
      address = IPAddr.new(request.remote_ip)
      render json: { errors: ["request issued from a forbidden network. Add #{address.to_string}/#{address.prefix} to your allowed adresses in your /profil"] }, status: :forbidden
    end
  end

  def ensure_token_is_not_expired
    if @api_token.expired?
      render json: { errors: ['token expired'] }, status: :unauthorized
    end
  end
end
