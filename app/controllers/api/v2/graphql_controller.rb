# frozen_string_literal: true

class API::V2::GraphqlController < API::V2::BaseController
  include GcTrackingConcern

  around_action :profile_with_vernier, only: :execute, if: :vernier_profile_requested?

  def execute
    result = execute_query
    @query_info = result.context.query_info

    render json: result
  rescue GraphQL::ParseError, JSON::ParserError => exception
    handle_parse_error(exception, :graphql_parse_failed)
  rescue ArgumentError => exception
    handle_parse_error(exception, :bad_request)
  rescue GraphQL::ExecutionError => exception
    # Raised outside schema execution (e.g. unknown stored queryId): surface the
    # message instead of letting the generic handler return an opaque 500.
    render json: { errors: [exception.to_h], data: nil }, status: :bad_request
  rescue => exception
    if Rails.env.production?
      handle_error_in_production(exception)
    else
      handle_error_in_development(exception)
    end
  end

  private

  # Execute with a cached parsed document when possible: stored queries are
  # static and integrators replay the same custom queries constantly, so
  # re-parsing the document on every request is pure overhead. The original
  # query string is reattached for logging (query_info). When the cache
  # returns nil (blank or unparseable query), fall back to the standard path,
  # which renders the usual GraphQL error response.
  def execute_query
    query_string = query
    document = API::V2::ParsedQueryCache.fetch(query_string)

    if document
      gql_query = GraphQL::Query.new(API::V2::Schema, document:, context:, variables:, operation_name:)
      gql_query.query_string = query_string
      gql_query.result
    else
      API::V2::Schema.execute(query: query_string, variables:, context:, operation_name:)
    end
  end

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
    variables = ensure_hash(params[:variables])

    # The stored queries shipped with a misspelled includeAnotations variable
    # for years; keep accepting it since clients rely on it.
    if params[:queryId].present? && variables.key?('includeAnotations') && !variables.key?('includeAnnotations')
      variables['includeAnnotations'] = variables['includeAnotations']
    end

    variables
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
