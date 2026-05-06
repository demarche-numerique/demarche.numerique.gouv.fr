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

  def authorized_demarche?(demarche, opendata: false)
    if internal_use?
      return true
    end

    if opendata && demarche.opendata?
      return true
    end

    self[:authorized] ||= {}

    if self[:authorized][demarche.id].nil?
      self[:authorized][demarche.id] = compute_demarche_authorization(demarche)
    end

    self[:authorized][demarche.id]
  end

  def query_info
    {
      graphql_query: query.query_string,
      graphql_variables: query.provided_variables&.to_json,
      graphql_mutation: mutation?,
      graphql_null_error: errors.any? { _1.is_a? GraphQL::InvalidNullError }.presence,
      graphql_timeout_error: errors.any? { _1.is_a? GraphQL::Schema::Timeout::TimeoutError }.presence,
      graphql_api_token_id: self[:api_token_id],
    }.compact
  end

  private

  def mutation?
    query.lookahead.selections.any? { _1.field.type.respond_to?(:mutation) }.presence
  rescue
    false
  end

  def compute_demarche_authorization(demarche)
    # procedure_ids and token are passed from graphql controller
    self[:procedure_ids]&.include?(demarche.id) || false
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
