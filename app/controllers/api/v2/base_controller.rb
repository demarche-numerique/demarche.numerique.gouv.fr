# frozen_string_literal: true

class API::V2::BaseController < ApplicationController
  # This controller is used for API v2 through api endpoint (/api/v2/graphql)
  # and through the web interface (/graphql). When used through the web interface,
  # we use connected administrateur to authenticate the request. We want CSRF protection
  # for the web interface, but not for the API endpoint. :null_session means that when the
  # request is not CSRF protected, we will not raise an exception,
  # but we will provide the controller with an empty session.
  protect_from_forgery with: :null_session, store: :cookie
  skip_before_action :setup_tracking
  before_action :authenticate_from_token
  before_action :ensure_authorized_network, if: -> { @api_token.present? }
  before_action :ensure_token_is_not_expired, if: -> { @api_token.present? }
  before_action :allow_only_public_queries, if: -> { unauthenticated? }

  before_action do
    Current.browser = 'api'
  end

  private

  def context
    if @api_token.present?
      ctx = @api_token.context
      ctx[:remote_ip] = request.remote_ip
      ctx
    # web interface (/graphql) give current_administrateur
    elsif current_administrateur.present?
      graphql_web_interface_context
    else
      unauthenticated_request_context
    end
  end

  def graphql_web_interface_context
    {
      administrateur_id: current_administrateur.id,
      procedure_ids: current_administrateur.procedure_ids,
      write_access: true,
      remote_ip: request.remote_ip,
    }
  end

  def unauthenticated_request_context
    {
      administrateur_id: nil,
      procedure_ids: [],
      write_access: false,
      remote_ip: request.remote_ip,
    }
  end

  def authenticate_from_token
    @api_token = authenticate_with_http_token { |t, _o| APIToken.authenticate(t) }

    if @api_token.present?
      @api_token.touch(:last_v2_authenticated_at)
      @api_token.store_new_ip(request.remote_ip)
      @current_user = @api_token.administrateur.user
      Current.user = @current_user
    end
  end

  def unauthenticated? = @api_token.blank? && current_administrateur.blank?

  def allow_only_public_queries
    query_id = params[:queryId]
    operation_name = params[:operationName]

    return if query_id == 'introspection'
    return if query_id == 'ds-query-v2' && operation_name == 'getDemarcheDescriptor'

    render json: graphql_error('Without a token, only the public getDemarcheDescriptor query and introspection are allowed', :forbidden), status: :forbidden
  end

  def ensure_authorized_network
    if @api_token.forbidden_network?(request.remote_ip)
      address = IPAddr.new(request.remote_ip)
      render json: graphql_error("Request issued from a forbidden network. Add #{address.to_string}/#{address.prefix} to your allowed adresses in your /profil", :forbidden), status: :forbidden
    end
  end

  def ensure_token_is_not_expired
    if @api_token.expired?
      render json: graphql_error('Token expired', :unauthorized), status: :unauthorized
    end
  end

  def graphql_error(message, code, exception_id: nil, backtrace: nil)
    {
      errors: [
        {
          message:,
          extensions: { code:, exception_id:, backtrace: }.compact,
        },
      ],
      data: nil,
    }
  end
end
