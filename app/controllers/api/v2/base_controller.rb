# frozen_string_literal: true

class API::V2::BaseController < ApplicationController
  # API v2 is authenticated by bearer token only: the session is never consulted
  # (see current_user below), so a stolen session cookie gives no access to the API.
  # :null_session is defense in depth rather than something the API relies on: a
  # request without a CSRF token (every API client) runs with an empty session,
  # so nothing cookie-based could leak in even if current_user were bypassed.
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
    else
      unauthenticated_request_context
    end
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
      @api_token.assign_first_ip!(request.remote_ip)
      @api_token.store_new_ip(request.remote_ip)
      @current_user = @api_token.administrateur.user
      Current.user = @current_user
    end
  end

  # Overrides Devise: the only identity this API knows is the one carried by the token.
  def current_user = @current_user

  def unauthenticated? = @api_token.blank?

  PUBLIC_OPERATIONS = ['getDemarcheDescriptor', 'getDemarcheDescriptors'].freeze

  def allow_only_public_queries
    query_id = params[:queryId]
    operation_name = params[:operationName]

    return if query_id == 'introspection'
    return if query_id == 'ds-query-v2' && PUBLIC_OPERATIONS.include?(operation_name)

    render json: graphql_error('Without a token, only the public getDemarcheDescriptor and getDemarcheDescriptors queries and introspection are allowed', :forbidden), status: :forbidden
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
