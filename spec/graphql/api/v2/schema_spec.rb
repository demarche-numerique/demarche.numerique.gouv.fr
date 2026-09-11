# frozen_string_literal: true

RSpec.describe API::V2::Schema do
  describe 'query complexity budget' do
    def complexity_of(operation_name, variables)
      query = GraphQL::Query.new(
        described_class,
        API::V2::StoredQuery::QUERY_V2,
        variables: variables.transform_keys(&:to_s),
        operation_name:,
        context: { internal_use: false }
      )
      expect(query.static_errors).to be_empty
      GraphQL::Analysis::AST.analyze_query(query, [GraphQL::Analysis::AST::QueryComplexity]).first
    end

    it 'keeps the complexity limit enabled' do
      expect(described_class.max_complexity).to be_a(Integer).and(be > 0)
    end

    # Canary: the heaviest query our own client sends (getDemarche, a full page of
    # dossiers with every include on) must stay under budget. If this fails, the schema
    # grew past the budget — re-measure and raise max_complexity deliberately rather than
    # letting legitimate integrations start getting complexity errors in production.
    it 'admits the heaviest legitimate query with headroom' do
      complexity = complexity_of('getDemarche', {
        demarcheNumber: 1, includeDossiers: true, first: 100,
        includeChamps: true, includeAnnotations: true, includeTraitements: true,
        includeInstructeurs: true, includeAvis: true, includeMessages: true,
        includeCorrections: true, includeGeometry: true, includeGroupeInstructeurs: true,
        includeService: true, includeRevision: true, includeRevisions: true,
        includePendingDeletedDossiers: true, includeDeletedDossiers: true,
        pendingDeletedFirst: 100, deletedFirst: 100,
      })

      # Sanity check that the query is genuinely heavy (guards a broken measurement).
      expect(complexity).to be > 20_000
      expect(complexity).to be < described_class.max_complexity
    end

    # The abuse vector: over-requesting the page size multiplies the per-node cost. The
    # query is rejected during analysis, before any resolver or DB access runs.
    it 'rejects an over-budget query before executing it' do
      result = described_class.execute(
        API::V2::StoredQuery::QUERY_V2,
        operation_name: 'getDemarche',
        variables: { 'demarcheNumber' => 1, 'includeDossiers' => true, 'first' => 250 },
        context: { internal_use: false }
      )

      expect(result['data']).to be_nil
      expect(result['errors'].map { _1['message'] }.join).to match(/complexity/i)
    end
  end

  # A client sending free text to a Date argument gets a proper validation error from
  # graphql-ruby on its own. Reporting it to Sentry on top of that was pure noise, and
  # since GraphQL::DateEncodingError embeds the offending value in its message, Sentry
  # split one defect into a new issue per distinct bad date.
  describe 'unparsable Date argument' do
    # Argument coercion runs before `authorized?` and `resolve`, so nothing referenced
    # here has to exist.
    let(:mutation) do
      <<~GRAPHQL
        mutation($value: ISO8601Date!) {
          dossierModifierAnnotationDate(input: {
            dossierId: "RG9zc2llci0x", instructeurId: "SW5zdHJ1Y3RldXItMQ==",
            annotationId: "Q2hhbXAtMQ==", value: $value
          }) { clientMutationId }
        }
      GRAPHQL
    end

    subject do
      described_class.execute(query: mutation, variables: { 'value' => '31 août 2000' }, context: { internal_use: false })
    end

    it 'reports nothing to Sentry and still returns a validation error to the client' do
      expect(Sentry).not_to receive(:capture_exception)
      expect(subject['data']).to be_nil
      expect(subject['errors'].map { _1['message'] }.join).to match(/provided invalid value/)
    end
  end

  # Logs and Sentry reports carry the query text and its variables, which are not
  # request parameters: nothing upstream filters them.
  describe '#query_info' do
    subject do
      described_class.execute(
        query: 'query getDemarche($demarcheNumber: Int!, $token: String) { demarche(number: $demarcheNumber) { id, token } }',
        variables: { 'demarcheNumber' => 1, 'token' => 'secret' },
        context: { internal_use: false }
      ).context.query_info
    end

    it 'applies the Rails parameter filter to the query text and the variables' do
      expect(subject[:graphql_query]).to end_with('{ id, [FILTERED] } }')
      expect(subject[:graphql_variables]).to eq({ 'demarcheNumber' => 1, 'token' => '[FILTERED]' }.to_json)
      expect(subject[:graphql_operation_name]).to eq('getDemarche')
    end
  end
end

RSpec.describe API::V2::Schema::Timeout do
  describe '#max_seconds' do
    let(:timeout_instance) { described_class.new(max_seconds: 30) }

    def query_with(context) = instance_double(GraphQL::Query, context:)

    it 'keeps the interactive ceiling for public API queries' do
      expect(timeout_instance.max_seconds(query_with(internal_use: false))).to eq(30)
    end

    # The datagouv export paginates over every public procedure from a cron job; the
    # interactive ceiling only truncated it.
    it 'gives internal serializer queries a batch-sized budget' do
      expect(timeout_instance.max_seconds(query_with(internal_use: true))).to be > 30
    end
  end
end
