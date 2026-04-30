# frozen_string_literal: true

class API::V2::GraphqlController < API::V2::BaseController
  include GcTrackingConcern

  around_action :profile_with_vernier, only: :execute, if: :vernier_profile_requested?

  def execute
    result = API::V2::Schema.execute(query:, variables:, context:, operation_name:)
    @query_info = result.context.query_info

    render json: result
  rescue GraphQL::ParseError, JSON::ParserError => exception
    handle_parse_error(exception, :graphql_parse_failed)
  rescue ArgumentError => exception
    handle_parse_error(exception, :bad_request)
  rescue => exception
    if Rails.env.production?
      handle_error_in_production(exception)
    else
      handle_error_in_development(exception)
    end
  end

  private

  def vernier_profile_requested?
    params[:profile].present?
  end

  def profile_with_vernier(&block)
    require 'vernier'

    out = Rails.root.join("tmp/vernier-graphql-#{Time.current.strftime('%Y%m%d-%H%M%S-%L')}.vernier.json").to_s
    Vernier.profile(out:, hooks: [:rails], &block)
    Rails.logger.info("[Vernier] GraphQL profile written to #{out}")
    Rails.logger.info("[Vernier] Open with: https://vernier.prof  — or  https://profiler.firefox.com")
  end

  def request_logs(logs)
    super

    logs.merge!(@query_info.presence || {})
  end

  def process_action(*args)
    super
  rescue ActionDispatch::Http::Parameters::ParseError => exception
    render json: graphql_error(exception.cause.message, :bad_request), status: :bad_request
  end

  def query
    if params[:queryId].present?
      API::V2::StoredQuery.get(params[:queryId])
    else
      params[:query]
    end
  end

  def variables
    ensure_hash(params[:variables])
  end

  def operation_name
    params[:operationName]
  end

  # Handle form data, JSON body, or a blank value
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash
      ambiguous_param
    when ActionController::Parameters
      ambiguous_param.to_unsafe_h
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end

  def handle_parse_error(exception, code)
    render json: graphql_error(exception.message, code), status: :bad_request
  end

  def handle_error_in_development(exception)
    logger.error exception.message
    logger.error exception.backtrace.join("\n")

    render json: graphql_error(exception.message, :internal_server_error, backtrace: exception.backtrace), status: :internal_server_error
  end

  def handle_error_in_production(exception)
    exception_id = SecureRandom.uuid
    Sentry.with_scope do |scope|
      scope.set_tags(exception_id:)
      Sentry.capture_exception(exception)
    end

    render json: graphql_error("Internal Server Error", :internal_server_error, exception_id:), status: :internal_server_error
  end
end
