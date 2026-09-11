# frozen_string_literal: true

class API::V2::Context < GraphQL::Query::Context
  # This method is used to check if a given fragment is used in the given query. We need that in
  # order to maintain backward compatibility for Types de Champ that we extended in later iterations
  # of our schema. If it is an introspection query, we assume all fragments are present.
  def has_fragment?(fragment_name)
    return true if query.nil?
    return true if introspection?

    self[:has_fragment] ||= Hash.new do |hash, fragment_name|
      visitor = HasFragment.new(query.document, fragment_name)
      visitor.visit
      hash[fragment_name] = visitor.found
    end
    self[:has_fragment][fragment_name]
  end

  def has_fragments?(fragment_names)
    fragment_names.any? { has_fragment?(_1) }
  end

  def introspection?
    query.selected_operation.name == "IntrospectionQuery"
  end

  def internal_use?
    self[:internal_use]
  end

  def write_access?
    self[:write_access]
  end

  def remote_ip
    self[:remote_ip]
  end

  def current_administrateur
    unless self[:administrateur_id]
      raise GraphQL::ExecutionError.new("Pour effectuer cette opération, vous avez besoin d’un jeton au nouveau format. Vous pouvez l’obtenir dans votre interface administrateur.", extensions: { code: :deprecated_token })
    end
    Administrateur.find(self[:administrateur_id])
  end

  # Grants access for the rest of the query to a demarche the caller just
  # created (e.g. the clone returned by demarcheCloner): it starts as a
  # brouillon and is not part of the token's procedure_ids snapshot.
  def authorize_demarche!(demarche)
    self[:authorized] ||= {}
    self[:authorized][demarche.id] = true
  end

  def authorized_demarche?(demarche, opendata: false)
    # `Procedure` has a `default_scope -> { kept }`, so `label.procedure`,
    # `dossier.revision.procedure`, … return nil once the démarche is hidden,
    # while the child rows still exist. Nothing can be authorized without a
    # démarche to authorize against.
    return false if demarche.nil?

    if internal_use?
      return true
    end

    if opendata && demarche.opendata? && !demarche.brouillon?
      return true
    end

    self[:authorized] ||= {}

    if self[:authorized][demarche.id].nil?
      self[:authorized][demarche.id] = compute_demarche_authorization(demarche)
    end

    self[:authorized][demarche.id]
  end

  # What logs and Sentry may carry about the query. The Rails parameter filter
  # applies to both the query text and the variables: neither is a request
  # parameter, so nothing filters them upstream.
  def query_info
    {
      graphql_query: filtered_query_string,
      graphql_variables: filtered_variables&.to_json,
      graphql_operation_name: query.operation_name,
      graphql_mutation: mutation?,
      graphql_null_error: errors.any? { _1.is_a? GraphQL::InvalidNullError }.presence,
      graphql_timeout_error: errors.any? { _1.is_a? GraphQL::Schema::Timeout::TimeoutError }.presence,
      graphql_api_token_id: self[:api_token_id],
    }.compact
  end

  private

  # filter_parameters holds symbols and strings until Rails compiles them into
  # regexps on the first request; the text filter has to accept both forms.
  def filtered_query_string
    patterns = Rails.application.config.filter_parameters.map { it.is_a?(Regexp) ? it : /#{Regexp.escape(it.to_s)}/i }
    query.query_string&.gsub(Regexp.union(patterns), "[FILTERED]")
  end

  def filtered_variables
    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(query.provided_variables) if query.provided_variables
  end

  def mutation?
    query.lookahead.selections.any? { _1.field.type.respond_to?(:mutation) }.presence
  rescue
    false
  end

  def compute_demarche_authorization(demarche)
    # procedure_ids and token are passed from graphql controller
    self[:procedure_ids].include?(demarche.id)
  end

  # This is a query AST visitor that we use to check
  # if a fragment with a given name is used in the given document.
  # We check for both inline and standalone fragments.
  class HasFragment < GraphQL::Language::Visitor
    def initialize(document, fragment_name)
      super(document)
      @fragment_name = fragment_name.to_s
      @found = false
    end

    attr_reader :found

    def on_inline_fragment(node, parent)
      if node.type.name == @fragment_name
        @found = true
      end

      super
    end

    def on_fragment_definition(node, parent)
      if node.type.name == @fragment_name
        @found = true
      end

      super
    end
  end
end
