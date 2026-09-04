# frozen_string_literal: true

RSpec.describe Connections::DossiersConnection, type: :graphql do
  let_it_be(:admin) { administrateurs.default }
  let_it_be(:procedure) { create(:procedure, :published, :for_individual, administrateurs: [admin], public_type_de_champs: [{}, {}]) }

  before_all { create(:dossier, :en_construction, :with_individual, :with_populated_champs, procedure:) }

  def execute(query)
    API::V2::Schema.execute(query, variables: { number: procedure.id }, context: { administrateur_id: admin.id, procedure_ids: admin.procedure_ids })
  end

  def count_queries(query)
    # Execute the query a first time so that shared queries (schema, token, …) are never counted
    execute(query)

    count = 0
    result = ActiveSupport::Notifications.subscribed(-> (*_args) { count += 1 }, 'sql.active_record') { execute(query) }

    expect(result['errors']).to be_nil
    count
  end

  # The connection exposes both Relay shapes; champs must be preloaded for each of them.
  shared_examples 'a shape preloading champs' do
    it 'does not run one query per dossier' do
      count_for_one_dossier = count_queries(query)

      create_list(:dossier, 3, :en_construction, :with_individual, :with_populated_champs, procedure:)

      expect(count_queries(query)).to eq(count_for_one_dossier)
    end
  end

  context 'when champs are selected through `nodes`' do
    let(:query) { NODES_CHAMPS_QUERY }

    it_behaves_like 'a shape preloading champs'
  end

  context 'when champs are selected through `edges { node }`' do
    let(:query) { EDGES_NODE_CHAMPS_QUERY }

    it_behaves_like 'a shape preloading champs'
  end

  context 'when linked dossiers are selected' do
    let_it_be(:procedure_with_link) { create(:procedure, :published, :for_individual, administrateurs: [admin], public_type_de_champs: [{ type: :dossier_link }]) }
    let(:query) { LINKED_DOSSIERS_QUERY }

    def execute(query)
      API::V2::Schema.execute(query, variables: { number: procedure_with_link.id }, context: { administrateur_id: admin.id, procedure_ids: admin.reload.procedure_ids })
    end

    # Each linked dossier lives on its own procedure, so its revision and
    # procedure are not shared with the dossiers of the connection.
    def create_dossier_with_link
      linked_procedure = create(:procedure, :published, :for_individual, administrateurs: [admin])
      linked_dossier = create(:dossier, :en_construction, :with_individual, procedure: linked_procedure)
      dossier = create(:dossier, :en_construction, :with_individual, :with_populated_champs, procedure: procedure_with_link)
      dossier.root_champs_public.first.update(value: linked_dossier.id)
    end

    it 'does not run one query per linked dossier' do
      create_dossier_with_link
      count_for_one_dossier = count_queries(query)

      3.times { create_dossier_with_link }

      expect(count_queries(query)).to eq(count_for_one_dossier)
    end
  end

  LINKED_DOSSIERS_QUERY = <<-GRAPHQL
  query getDemarche($number: Int!) {
    demarche(number: $number) {
      dossiers {
        nodes {
          id
          champs {
            id
            ... on DossierLinkChamp {
              dossier {
                id
                state
                demandeur { id }
              }
            }
          }
        }
      }
    }
  }
  GRAPHQL

  NODES_CHAMPS_QUERY = <<-GRAPHQL
  query getDemarche($number: Int!) {
    demarche(number: $number) {
      dossiers {
        nodes {
          id
          champs {
            id
            label
          }
        }
      }
    }
  }
  GRAPHQL

  EDGES_NODE_CHAMPS_QUERY = <<-GRAPHQL
  query getDemarche($number: Int!) {
    demarche(number: $number) {
      dossiers {
        edges {
          node {
            id
            champs {
              id
              label
            }
          }
        }
      }
    }
  }
  GRAPHQL
end
