# frozen_string_literal: true

describe API::V2::GraphqlController do
  let_it_be(:admin) { administrateurs.default }
  let_it_be(:generated_token) { APIToken.generate(admin) }
  let(:token) { generated_token.second }
  let_it_be(:procedure) { create(:procedure, :published, :for_individual, :with_service, administrateurs: [admin], public_type_de_champs: [{}, { type: :piece_justificative }, { type: :siret }, { type: :repetition, mandatory: true, children: [{}, { type: :piece_justificative }, { type: :siret }] }]) }
  let(:authorization_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

  let(:query_id) { 'ds-query-v2' }
  let(:variables) { {} }
  let(:operation_name) { nil }
  let(:body) { JSON.parse(subject.body, symbolize_names: true) }
  let(:gql_data) { body[:data] }
  let(:gql_errors) { body[:errors] }

  let(:dossiers_count) { dossiers_per_state * 3 }

  subject { post :execute, params: { queryId: query_id, variables: variables, operationName: operation_name }.compact, as: :json }

  before do
    request.env['HTTP_AUTHORIZATION'] = authorization_header
  end

  MAX_QUERY_COUNT = 80

  describe 'demarche.dossiers' do
    let(:operation_name) { 'getDemarche' }
    let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, includeTraitements: true, includeRevision: true, includeRevisions: true, includeMessages: true, includeAssignments: true } }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_populated_champs, :with_commentaires, procedure:) }
    let(:dossiers_en_instruction) { create_list(:dossier, dossiers_per_state, :en_instruction, :with_individual, :with_populated_champs, :with_commentaires, procedure:) }
    let(:dossiers_accepte) { create_list(:dossier, dossiers_per_state, :accepte, :with_individual, :with_populated_champs, :with_commentaires, procedure:) }
    let(:dossiers_refuse) { create_list(:dossier, dossiers_per_state, :refuse, :with_individual, :with_populated_champs, :with_commentaires, procedure:) }

    it "should not have n+1 on one dossier" do
      query_count = 0

      dossier
      # Execute the query first time to ensure shared queries are never counted in the query counter
      post :execute, params: { queryId: query_id, variables: variables, operationName: operation_name }.compact, as: :json
      ActiveSupport::Notifications.subscribed(lambda { |*_args| query_count += 1 }, "sql.active_record") { subject }

      expect(gql_errors).to be_nil
      expect(gql_data[:demarche][:dossiers][:nodes].count).to eq(1)
      expect(query_count).to be <= MAX_QUERY_COUNT
    end

    # `Procedure.for_api_v2` loads the types de champ of the démarche's active
    # revisions, then the dossiers of the connection carry their own revision:
    # DossierPreloader must reuse it rather than load its types de champ again.
    it "loads the types de champ of the dossiers' revision once" do
      variables = { demarcheNumber: procedure.id, includeDossiers: true, includeChamps: true, includeTraitements: false }
      dossier
      revision_queries = []
      callback = lambda { |*args| revision_queries << args.last[:sql] if args.last[:sql].include?('"procedure_revision_types_de_champ"') }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        post :execute, params: { queryId: query_id, variables:, operationName: operation_name }, as: :json
      end

      expect(gql_errors).to be_nil
      expect(revision_queries.size).to eq(2)
    end

    context "with 3 dossiers per state" do
      let(:dossiers_per_state) { 3 }

      it "should not have n+1", :slow do
        query_count = 0

        dossier
        dossiers_en_instruction
        dossiers_accepte
        dossiers_refuse
        ActiveSupport::Notifications.subscribed(lambda { |*_args| query_count += 1 }, "sql.active_record") { subject }

        expect(gql_errors).to be_nil
        expect(gql_data[:demarche][:dossiers][:nodes].count).to eq(dossiers_count + 1)
        expect(query_count).to be <= MAX_QUERY_COUNT
      end
    end
  end

  describe 'demarche.dossiers with entreprise demandeur' do
    let_it_be(:procedure_entreprise) { create(:procedure, :published, :with_service, administrateurs: [admin], public_type_de_champs: [{}]) }

    # A custom query without champs skips the DossierPreloader (which marks the
    # demandeur's champ_data association as loaded), so PersonneMorale.address
    # has to resolve champ_data itself — it must batch instead of one query per dossier.
    let(:query) do
      <<~GRAPHQL
        query($demarcheNumber: Int!) {
          demarche(number: $demarcheNumber) {
            dossiers {
              nodes {
                demandeur {
                  ... on PersonneMorale { siret address { label } }
                }
              }
            }
          }
        }
      GRAPHQL
    end
    let(:variables) { { demarcheNumber: procedure_entreprise.id } }

    subject { post :execute, params: { query:, variables: }, as: :json }

    it "batches etablissement champ_data lookups (PersonneMorale.address)" do
      create_list(:dossier, 5, :en_construction, :with_entreprise, procedure: procedure_entreprise)

      etablissement_champ_queries = []
      callback = lambda do |_name, _started, _finished, _unique_id, payload|
        etablissement_champ_queries << payload[:sql] if payload[:sql]&.include?('"champs"."etablissement_id"')
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { subject }

      expect(gql_errors).to be_nil
      expect(gql_data[:demarche][:dossiers][:nodes].count).to eq(5)
      expect(etablissement_champ_queries.size).to be <= 1
    end
  end
end
