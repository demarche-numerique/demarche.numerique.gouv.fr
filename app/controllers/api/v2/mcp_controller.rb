# frozen_string_literal: true

# The MCP endpoint (Model Context Protocol, Streamable HTTP transport) of the
# form editor: see DraftEditorTools. Authenticated as the GraphQL API is, by
# the API token of an administrateur, its networks and its expiry.
#
# Stateless: every POST carries one JSON-RPC message and is answered in JSON.
# The server never calls the client back, so it opens no SSE stream.
class API::V2::McpController < API::V2::BaseController
  skip_before_action :allow_only_public_queries
  before_action :ensure_authenticated

  def create
    response_body = DraftEditorTools.server(context).handle_json(request.raw_post)

    if response_body.present?
      render json: response_body
    else # a notification: nothing to answer
      head :accepted
    end
  end

  # GET would open the stream of the messages the server initiates.
  def stream
    response.headers['Allow'] = 'POST'
    head :method_not_allowed
  end

  private

  def ensure_authenticated
    return if @api_token.present?

    response.headers['WWW-Authenticate'] = 'Bearer'
    render json: { jsonrpc: '2.0', id: nil, error: { code: -32001, message: 'An API token is required: Authorization: Bearer <token>' } }, status: :unauthorized
  end
end
