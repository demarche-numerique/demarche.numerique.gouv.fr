# frozen_string_literal: true

describe API::V2::GraphqlController do
  let(:admin) { administrateurs(:default_admin) }
  let(:generated_token) { APIToken.generate(admin) }
  let(:api_token) { generated_token.first }
  let(:token) { generated_token.second }
  let(:legacy_token) { APIToken.send(:unpack, token)[:plain_token] }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service, administrateurs: [admin], types_de_champ_public:) }
  let(:types_de_champ_public) { [] }
  let(:dossier)  { create(:dossier, :en_construction, :with_individual, procedure:, depose_at: 4.days.ago) }
  let(:dossier1) { create(:dossier, :en_construction, :with_individual, procedure:, en_construction_at: 1.day.ago, depose_at: 3.days.ago) }
  let(:dossier2) { create(:dossier, :en_construction, :with_individual, :archived, procedure:, en_construction_at: 3.days.ago, depose_at: 2.days.ago) }
  let(:dossier3) { create(:dossier, :accepte, :with_individual, procedure:, depose_at: 1.day.ago) }
  let(:dossier_accepte) { create(:dossier, :accepte, :with_individual, procedure:) }
  let(:dossier_accepte1) { create(:dossier, :accepte, :with_individual, procedure:) }
  let(:dossier_accepte2) { create(:dossier, :accepte, :with_individual, procedure:) }
  let(:dossiers) { [dossier] }
  let(:instructeur) { create(:instructeur, followed_dossiers: dossiers) }
  let(:authorization_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

  before do
    instructeur.assign_to_procedure(procedure)
  end

  let(:query_id) { nil }
  let(:variables) { {} }
  let(:operation_name) { nil }
  let(:body) { JSON.parse(subject.body, symbolize_names: true) }
  let(:gql_data) { body[:data] }
  let(:gql_errors) { body[:errors] }

  subject { post :execute, params: { queryId: query_id, variables: variables, operationName: operation_name }.compact, as: :json }

  before do
    request.env['HTTP_AUTHORIZATION'] = authorization_header
  end

  describe 'introspection' do
    let(:query_id) { 'introspection' }
    let(:operation_name) { 'IntrospectionQuery' }
    let(:champ_descriptor) { gql_data[:__schema][:types].find { _1[:name] == 'ChampDescriptor' } }

    it {
      expect(gql_errors).to be_nil
      expect(gql_data[:__schema]).not_to be_nil
      expect(champ_descriptor).not_to be_nil
      expect(champ_descriptor[:fields].find { _1[:name] == 'options' }).to be_nil
    }
  end

  describe 'when not authenticated' do
    let(:variables) { { dossierNumber: dossier.id } }
    let(:operation_name) { 'getDossier' }
    let!(:authorization_header) { nil }

    context 'with query' do
      let(:query) { 'query getDossier($dossierNumber: Int!) { dossier(number: $dossierNumber) { id } }' }

      it { expect(gql_errors.first[:message]).to eq('Without a token, only persisted queries are allowed') }
    end

    context 'with queryId' do
      let(:query_id) { 'ds-query-v2' }

      it { expect(gql_errors.first[:message]).to eq('An object of type Dossier was hidden due to permissions') }
    end
  end

  describe 'ds-query-v2' do
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, depose_at: 4.days.ago) }
    let(:query_id) { 'ds-query-v2' }

    context 'not found operation id' do
      let(:query_id) { 'ds-query-v0' }

      it {
        expect(gql_errors.first[:message]).to eq('No query with id "ds-query-v0"')
      }
    end

    context 'not found operation name' do
      let(:operation_name) { 'getStuff' }

      it {
        expect(gql_errors.first[:message]).to eq('No operation named "getStuff"')
      }
    end

    context 'timeout' do
      let(:variables) { { dossierNumber: dossier.id } }
      let(:operation_name) { 'getDossier' }

      before { allow_any_instance_of(API::V2::Schema::Timeout).to receive(:max_seconds).and_return(0) }

      it {
        expect(gql_errors.first[:message]).to eq('Timeout on Query.dossier')
        expect(gql_errors.first[:extensions]).to eq({ code: 'timeout' })
      }
    end

    context 'getDossier' do
      let(:variables) { { dossierNumber: dossier.id } }
      let(:operation_name) { 'getDossier' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossier][:connectionUsager]).to eq('password')
        expect(gql_data[:dossier][:demandeur][:__typename]).to eq('PersonnePhysique')
        expect(gql_data[:dossier][:demandeur][:nom]).to eq(dossier.individual.nom)
        expect(gql_data[:dossier][:demandeur][:prenom]).to eq(dossier.individual.prenom)
      }

      context 'not found' do
        let(:variables) { { dossierNumber: 0 } }

        it {
          expect(gql_errors.first[:message]).to eq('Dossier not found')
          expect(gql_errors.first[:extensions]).to eq({ code: 'not_found' })
        }
      end

      context 'with entreprise' do
        let(:types_de_champ_public) { [{ type: :siret }] }
        let(:procedure) { create(:procedure, :published, :with_service, administrateurs: [admin], types_de_champ_public:) }
        let(:dossier) { create(:dossier, :en_construction, :with_entreprise, :with_populated_champs, procedure: procedure) }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossier][:demandeur][:__typename]).to eq('PersonneMorale')
          expect(gql_data[:dossier][:demandeur][:siret]).to eq(dossier.etablissement.siret)
          expect(gql_data[:dossier][:demandeur][:libelleNaf]).to eq(dossier.etablissement.libelle_naf)
        }

        context 'when in degraded mode' do
          before { dossier.etablissement.update(adresse: nil) }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:dossier][:id]).to eq(dossier.to_typed_id)
            expect(gql_data[:dossier][:demandeur][:__typename]).to eq('PersonneMoraleIncomplete')
            expect(gql_data[:dossier][:demandeur][:siret]).to eq(dossier.etablissement.siret)
            expect(gql_data[:dossier][:demandeur][:libelleNaf]).to be_nil
          }
        end
      end

      context 'columns' do
        let(:types_de_champ_public) do
          [
            { libelle: 'label text' },
            { type: :integer_number, libelle: 'label integer_number' },
            { type: :decimal_number, libelle: 'label decimal_number' },
            { type: :checkbox, libelle: 'label checkbox' },
            { type: :piece_justificative, libelle: 'label piece_justificative' },
            { type: :multiple_drop_down_list, libelle: 'label multiple_drop_down_list' },
            { type: :siret, libelle: 'label entreprise' },
          ]
        end
        let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_populated_champs, procedure:) }
        let(:columns) { gql_data[:dossier][:champs].flat_map { _1[:columns] } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossier][:champs].size).to eq(7)
          expect(columns.size).to eq(17)

          expect(columns[0]).to include(label: "label text", value: 'text')
          expect(columns[1]).to include(label: "label integer_number", value: "42")
          expect(columns[2]).to include(label: "label decimal_number", value: 42.1)
          expect(columns[3]).to include(label: "label checkbox", value: true)
          expect(columns[4][:value].first).to include(__typename: "File", filename: "toto.txt", contentType: "text/plain")
          expect(columns[5]).to include(label: "label multiple_drop_down_list", value: ["val1", "val2"])

          expect(columns[6]).to include(label: "label entreprise – SIRET", value: '44011762001530')
          expect(columns[7]).to include(label: "label entreprise – Entreprise raison sociale", value: 'GRTGAZ')
          expect(columns[15]).to include(label: "label entreprise – SIRET – Département", value: '92')
          expect(columns[16]).to include(label: "label entreprise – SIRET – Région", value: 'Île-de-France')
        }
      end
    end

    context 'getDemarche' do
      let(:variables) { { demarcheNumber: procedure.id } }
      let(:operation_name) { 'getDemarche' }

      before { dossier }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:demarche][:id]).to eq(procedure.to_typed_id)
        expect(gql_data[:demarche][:dossiers]).to be_nil
      }

      context 'not found' do
        let(:variables) { { demarcheNumber: 0 } }

        it {
          expect(gql_errors.first[:message]).to eq('Demarche not found')
          expect(gql_errors.first[:extensions]).to eq({ code: 'not_found' })
        }
      end

      context 'include Revision' do
        let(:variables) { { demarcheNumber: procedure.id, includeRevision: true } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarche][:id]).to eq(procedure.to_typed_id)
          expect(gql_data[:demarche][:activeRevision]).not_to be_nil
        }
      end

      context 'include Dossiers' do
        def cursor_for(item, column)
          cursor = [item.reload.read_attribute(column).utc.strftime("%Y-%m-%dT%H:%M:%S.%NZ"), item.id].join(';')
          API::V2::Schema.cursor_encoder.encode(cursor, nonce: true)
        end

        let(:order_column) { :depose_at }
        let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true } }
        let(:start_cursor) { cursor_for(dossier, order_column) }
        let(:end_cursor) { cursor_for(dossier3, order_column) }

        before { dossier1; dossier2; dossier3 }

        context 'depose_at' do
          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:demarche][:id]).to eq(procedure.to_typed_id)
            expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(4)
            expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
            expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
            expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
            expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
          }

          context 'first' do
            let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2 } }
            let(:end_cursor) { cursor_for(dossier1, order_column) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
              expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }

            context 'with deprecated order' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, order: 'DESC' } }
              let(:start_cursor) { cursor_for(dossier3, order_column) }
              let(:end_cursor) { cursor_for(dossier2, order_column) }

              it {
                allow(Rails.logger).to receive(:info)
                expect(Rails.logger).to receive(:info).with("{\"message\":\"CursorConnection: using deprecated order [#{admin.email}]\",\"user_id\":#{admin.user.id}}")

                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }

              context 'after' do
                let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, after: current_cursor, order: 'DESC' } }
                let(:current_cursor) { cursor_for(dossier2, order_column) }
                let(:start_cursor) { cursor_for(dossier1, order_column) }
                let(:end_cursor) { cursor_for(dossier, order_column) }

                it {
                  allow(Rails.logger).to receive(:info)
                  expect(Rails.logger).to receive(:info).with("{\"message\":\"CursorConnection: using deprecated order [#{admin.email}]\",\"user_id\":#{admin.user.id}}")

                  expect(gql_errors).to be_nil
                  expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
                }
              end

              context 'before' do
                let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, before: current_cursor, order: 'DESC' } }
                let(:current_cursor) { cursor_for(dossier1, order_column) }
                let(:start_cursor) { cursor_for(dossier3, order_column) }
                let(:end_cursor) { cursor_for(dossier2, order_column) }

                it {
                  allow(Rails.logger).to receive(:info)
                  expect(Rails.logger).to receive(:info).with("{\"message\":\"CursorConnection: using deprecated order [#{admin.email}]\",\"user_id\":#{admin.user.id}}")

                  expect(gql_errors).to be_nil
                  expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                  expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
                }
              end
            end

            context 'after' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, after: current_cursor } }
              let(:current_cursor) { cursor_for(dossier1, order_column) }
              let(:start_cursor) { cursor_for(dossier2, order_column) }
              let(:end_cursor) { cursor_for(dossier3, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }

              context 'with deleted' do
                let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true } }

                before { dossier.hide_and_keep_track!(dossier.user, DeletedDossier.reasons.fetch(:user_request)) }

                it {
                  expect(gql_errors).to be_nil
                  expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(3)
                }

                context 'second page not changed' do
                  let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, after: current_cursor } }

                  it {
                    expect(gql_errors).to be_nil
                    expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                    expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
                    expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
                    expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                    expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
                  }
                end
              end
            end

            context 'before' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, before: current_cursor } }
              let(:current_cursor) { cursor_for(dossier2, order_column) }
              let(:start_cursor) { cursor_for(dossier, order_column) }
              let(:end_cursor) { cursor_for(dossier1, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end
          end

          context 'last' do
            let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, last: 2 } }
            let(:start_cursor) { cursor_for(dossier2, order_column) }
            let(:end_cursor) { cursor_for(dossier3, order_column) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
              expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }

            context 'before' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, last: 2, before: current_cursor } }
              let(:current_cursor) { cursor_for(dossier2, order_column) }
              let(:start_cursor) { cursor_for(dossier, order_column) }
              let(:end_cursor) { cursor_for(dossier1, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end

            context 'after' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, last: 2, after: current_cursor } }
              let(:current_cursor) { cursor_for(dossier1, order_column) }
              let(:start_cursor) { cursor_for(dossier2, order_column) }
              let(:end_cursor) { cursor_for(dossier3, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end
          end
        end

        context 'updated_at' do
          let(:order_column) { :updated_at }

          context 'first' do
            let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, updatedSince: 10.days.ago.iso8601 } }
            let(:end_cursor) { cursor_for(dossier1, order_column) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
              expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }

            context 'after' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, after: current_cursor, updatedSince: 10.days.ago.iso8601 } }
              let(:current_cursor) { cursor_for(dossier1, order_column) }
              let(:start_cursor) { cursor_for(dossier2, order_column) }
              let(:end_cursor) { cursor_for(dossier3, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end

            context 'before' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, first: 2, before: current_cursor, updatedSince: 10.days.ago.iso8601 } }
              let(:current_cursor) { cursor_for(dossier2, order_column) }
              let(:start_cursor) { cursor_for(dossier, order_column) }
              let(:end_cursor) { cursor_for(dossier1, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end
          end

          context 'last' do
            let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, last: 2, updatedSince: 10.days.ago.iso8601 } }
            let(:start_cursor) { cursor_for(dossier2, order_column) }
            let(:end_cursor) { cursor_for(dossier3, order_column) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
              expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
              expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }

            context 'before' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, last: 2, before: current_cursor, updatedSince: 10.days.ago.iso8601 } }
              let(:current_cursor) { cursor_for(dossier2, order_column) }
              let(:start_cursor) { cursor_for(dossier, order_column) }
              let(:end_cursor) { cursor_for(dossier1, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end

            context 'after' do
              let(:variables) { { demarcheNumber: procedure.id, includeDossiers: true, last: 2, after: current_cursor, updatedSince: 10.days.ago.iso8601 } }
              let(:current_cursor) { cursor_for(dossier1, order_column) }
              let(:start_cursor) { cursor_for(dossier2, order_column) }
              let(:end_cursor) { cursor_for(dossier3, order_column) }

              it {
                expect(gql_errors).to be_nil
                expect(gql_data[:demarche][:dossiers][:nodes].size).to eq(2)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasNextPage]).to be_falsey
                expect(gql_data[:demarche][:dossiers][:pageInfo][:hasPreviousPage]).to be_truthy
                expect(gql_data[:demarche][:dossiers][:pageInfo][:startCursor]).to eq(start_cursor)
                expect(gql_data[:demarche][:dossiers][:pageInfo][:endCursor]).to eq(end_cursor)
              }
            end
          end
        end
      end

      context 'include deleted Dossiers' do
        def cursor_for(item)
          cursor = [item.reload.deleted_at.utc.strftime("%Y-%m-%dT%H:%M:%S.%NZ"), item.id].join(';')
          API::V2::Schema.cursor_encoder.encode(cursor, nonce: true)
        end

        let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedSince: 2.weeks.ago.iso8601 } }
        let(:deleted_dossier) { DeletedDossier.create_from_dossier(dossier_accepte, DeletedDossier.reasons.fetch(:user_request)).tap { _1.update(deleted_at: 4.days.ago) } }
        let(:deleted_dossier1) { DeletedDossier.create_from_dossier(dossier_accepte1, DeletedDossier.reasons.fetch(:user_request)).tap { _1.update(deleted_at: 3.days.ago) } }
        let(:deleted_dossier2) { DeletedDossier.create_from_dossier(dossier_accepte2, DeletedDossier.reasons.fetch(:user_request)).tap { _1.update(deleted_at: 2.days.ago) } }
        let(:deleted_dossier3) { DeletedDossier.create_from_dossier(dossier3, DeletedDossier.reasons.fetch(:user_request)).tap { _1.update(deleted_at: 1.day.ago) } }

        let(:start_cursor) { cursor_for(deleted_dossier) }
        let(:end_cursor) { cursor_for(deleted_dossier3) }

        before { deleted_dossier; deleted_dossier1; deleted_dossier2; deleted_dossier3 }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarche][:id]).to eq(procedure.to_typed_id)
          expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(4)
          expect(gql_data[:demarche][:deletedDossiers][:nodes].first[:id]).to eq(deleted_dossier.to_typed_id)
          expect(gql_data[:demarche][:deletedDossiers][:nodes].first[:dateSupression]).to eq(deleted_dossier.deleted_at.iso8601)
        }

        context 'first' do
          let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedFirst: 2 } }
          let(:end_cursor) { cursor_for(deleted_dossier1) }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(2)
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasNextPage]).to be_truthy
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasPreviousPage]).to be_falsey
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
          }

          context 'after' do
            let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedFirst: 2, deletedAfter: current_cursor } }
            let(:current_cursor) { cursor_for(deleted_dossier1) }
            let(:start_cursor) { cursor_for(deleted_dossier2) }
            let(:end_cursor) { cursor_for(deleted_dossier3) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasNextPage]).to be_falsey
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasPreviousPage]).to be_truthy
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end

          context 'before' do
            let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedFirst: 2, deletedBefore: current_cursor } }
            let(:current_cursor) { cursor_for(deleted_dossier2) }
            let(:start_cursor) { cursor_for(deleted_dossier) }
            let(:end_cursor) { cursor_for(deleted_dossier1) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasNextPage]).to be_truthy
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasPreviousPage]).to be_falsey
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end
        end

        context 'last' do
          let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedLast: 2 } }
          let(:start_cursor) { cursor_for(deleted_dossier2) }
          let(:end_cursor) { cursor_for(deleted_dossier3) }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(2)
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasNextPage]).to be_falsey
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasPreviousPage]).to be_truthy
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
            expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
          }

          context 'before' do
            let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedLast: 2, deletedBefore: current_cursor } }
            let(:current_cursor) { cursor_for(deleted_dossier2) }
            let(:start_cursor) { cursor_for(deleted_dossier) }
            let(:end_cursor) { cursor_for(deleted_dossier1) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasNextPage]).to be_truthy
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasPreviousPage]).to be_falsey
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end

          context 'after' do
            let(:variables) { { demarcheNumber: procedure.id, includeDeletedDossiers: true, deletedLast: 2, deletedAfter: current_cursor } }
            let(:current_cursor) { cursor_for(deleted_dossier1) }
            let(:start_cursor) { cursor_for(deleted_dossier2) }
            let(:end_cursor) { cursor_for(deleted_dossier3) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:deletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasNextPage]).to be_falsey
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:hasPreviousPage]).to be_truthy
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:deletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end
        end
      end

      context 'include pending deleted Dossiers' do
        def cursor_for(item)
          cursor = [(item.reload.en_construction? ? item.hidden_by_user_at : item.hidden_by_administration_at).utc.strftime("%Y-%m-%dT%H:%M:%S.%NZ"), item.id].join(';')
          API::V2::Schema.cursor_encoder.encode(cursor, nonce: true)
        end

        let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedSince: 2.weeks.ago.iso8601 } }

        let(:pending_deleted_dossier) do
          dossier.hide_and_keep_track!(dossier.user, DeletedDossier.reasons.fetch(:user_request))
          dossier.tap { _1.update(hidden_by_user_at: 4.days.ago) }
        end
        let(:pending_deleted_dossier1) do
          dossier_accepte.hide_and_keep_track!(instructeur, DeletedDossier.reasons.fetch(:instructeur_request))
          dossier_accepte.tap { _1.update(hidden_by_administration_at: 3.days.ago) }
        end
        let(:pending_deleted_dossier2) do
          dossier1.hide_and_keep_track!(dossier.user, DeletedDossier.reasons.fetch(:user_request))
          dossier1.tap { _1.update(hidden_by_user_at: 2.days.ago) }
        end
        let(:pending_deleted_dossier3) do
          dossier_accepte1.hide_and_keep_track!(instructeur, DeletedDossier.reasons.fetch(:instructeur_request))
          dossier_accepte1.tap { _1.update(hidden_by_administration_at: 1.day.ago) }
        end

        let(:start_cursor) { cursor_for(pending_deleted_dossier) }
        let(:end_cursor) { cursor_for(pending_deleted_dossier3) }

        before { pending_deleted_dossier; pending_deleted_dossier1; pending_deleted_dossier2; pending_deleted_dossier3 }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarche][:id]).to eq(procedure.to_typed_id)
          expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(4)
          expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].first[:id]).to eq(GraphQL::Schema::UniqueWithinType.encode('DeletedDossier', dossier.id))
          expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].second[:id]).to eq(GraphQL::Schema::UniqueWithinType.encode('DeletedDossier', dossier_accepte.id))
          expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].first[:dateSupression]).to eq(pending_deleted_dossier.hidden_by_user_at.iso8601)
          expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].second[:dateSupression]).to eq(pending_deleted_dossier1.hidden_by_administration_at.iso8601)
          expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].first[:dateSupression] < gql_data[:demarche][:pendingDeletedDossiers][:nodes].second[:dateSupression]).to be_truthy
        }

        context 'first' do
          let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedFirst: 2 } }
          let(:end_cursor) { cursor_for(pending_deleted_dossier1) }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(2)
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasNextPage]).to be_truthy
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasPreviousPage]).to be_falsey
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
          }

          context 'after' do
            let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedFirst: 2, pendingDeletedAfter: current_cursor } }
            let(:current_cursor) { cursor_for(pending_deleted_dossier1) }
            let(:start_cursor) { cursor_for(pending_deleted_dossier2) }
            let(:end_cursor) { cursor_for(pending_deleted_dossier3) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasNextPage]).to be_falsey
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasPreviousPage]).to be_truthy
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end

          context 'before' do
            let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedFirst: 2, pendingDeletedBefore: current_cursor } }
            let(:current_cursor) { cursor_for(pending_deleted_dossier2) }
            let(:start_cursor) { cursor_for(pending_deleted_dossier) }
            let(:end_cursor) { cursor_for(pending_deleted_dossier1) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasNextPage]).to be_truthy
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasPreviousPage]).to be_falsey
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end
        end

        context 'last' do
          let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedLast: 2 } }
          let(:start_cursor) { cursor_for(pending_deleted_dossier2) }
          let(:end_cursor) { cursor_for(pending_deleted_dossier3) }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(2)
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasNextPage]).to be_falsey
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasPreviousPage]).to be_truthy
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
            expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
          }

          context 'before' do
            let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedLast: 2, pendingDeletedBefore: current_cursor } }
            let(:current_cursor) { cursor_for(pending_deleted_dossier2) }
            let(:start_cursor) { cursor_for(pending_deleted_dossier) }
            let(:end_cursor) { cursor_for(pending_deleted_dossier1) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasNextPage]).to be_truthy
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasPreviousPage]).to be_falsey
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end

          context 'after' do
            let(:variables) { { demarcheNumber: procedure.id, includePendingDeletedDossiers: true, pendingDeletedLast: 2, pendingDeletedAfter: current_cursor } }
            let(:current_cursor) { cursor_for(pending_deleted_dossier1) }
            let(:start_cursor) { cursor_for(pending_deleted_dossier2) }
            let(:end_cursor) { cursor_for(pending_deleted_dossier3) }

            it {
              expect(gql_errors).to be_nil
              expect(gql_data[:demarche][:pendingDeletedDossiers][:nodes].size).to eq(2)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasNextPage]).to be_falsey
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:hasPreviousPage]).to be_truthy
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:startCursor]).to eq(start_cursor)
              expect(gql_data[:demarche][:pendingDeletedDossiers][:pageInfo][:endCursor]).to eq(end_cursor)
            }
          end
        end
      end
    end

    context 'getGroupeInstructeur' do
      let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
      let(:variables) { { groupeInstructeurNumber: groupe_instructeur.id } }
      let(:operation_name) { 'getGroupeInstructeur' }

      before { dossier }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
        expect(gql_data[:groupeInstructeur][:dossiers]).to be_nil
      }

      context 'not found' do
        let(:variables) { { groupeInstructeurNumber: 0 } }

        it {
          expect(gql_errors.first[:message]).to eq('GroupeInstructeurWithDossiers not found')
          expect(gql_errors.first[:extensions]).to eq({ code: 'not_found' })
        }
      end

      context 'include Dossiers' do
        let(:variables) { { groupeInstructeurNumber: groupe_instructeur.id, includeDossiers: true } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
          expect(gql_data[:groupeInstructeur][:dossiers][:nodes].size).to eq(1)
        }
      end

      context 'include deleted Dossiers' do
        let(:variables) { { groupeInstructeurNumber: groupe_instructeur.id, includeDeletedDossiers: true, deletedSince: 2.weeks.ago.iso8601 } }
        let(:deleted_dossier) { DeletedDossier.create_from_dossier(dossier_accepte, DeletedDossier.reasons.fetch(:user_request)) }

        before { deleted_dossier }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
          expect(gql_data[:groupeInstructeur][:deletedDossiers][:nodes].size).to eq(1)
          expect(gql_data[:groupeInstructeur][:deletedDossiers][:nodes].first[:id]).to eq(deleted_dossier.to_typed_id)
          expect(gql_data[:groupeInstructeur][:deletedDossiers][:nodes].first[:dateSupression]).to eq(deleted_dossier.deleted_at.iso8601)
        }
      end

      context 'include pending deleted Dossiers' do
        let(:variables) { { groupeInstructeurNumber: groupe_instructeur.id, includePendingDeletedDossiers: true, pendingDeletedSince: 2.weeks.ago.iso8601 } }

        before {
          dossier.hide_and_keep_track!(dossier.user, DeletedDossier.reasons.fetch(:user_request))
          travel_to(3.hours.ago) {
            dossier_accepte.hide_and_keep_track!(instructeur, DeletedDossier.reasons.fetch(:instructeur_request))
          }
        }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
          expect(gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].size).to eq(2)
          expect(gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].first[:id]).to eq(GraphQL::Schema::UniqueWithinType.encode('DeletedDossier', dossier_accepte.id))
          expect(gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].second[:id]).to eq(GraphQL::Schema::UniqueWithinType.encode('DeletedDossier', dossier.id))
          expect(gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].first[:dateSupression]).to eq(dossier_accepte.hidden_by_administration_at.iso8601)
          expect(gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].second[:dateSupression]).to eq(dossier.hidden_by_user_at.iso8601)
          expect(gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].first[:dateSupression] < gql_data[:groupeInstructeur][:pendingDeletedDossiers][:nodes].second[:dateSupression])
        }
      end
    end

    context 'getDemarcheDescriptor' do
      let(:operation_name) { 'getDemarcheDescriptor' }
      let(:types_de_champ_public) { [{ type: :text }, { type: :piece_justificative }, { type: :regions }] }

      context 'find by number' do
        let(:variables) { { demarche: { number: procedure.id }, includeRevision: true } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheDescriptor][:id]).to eq(procedure.to_typed_id)
          expect(gql_data[:demarcheDescriptor][:demarcheURL]).to match("commencer/#{procedure.path}")
        }
      end

      context 'not found' do
        let(:variables) { { demarche: { number: 0 } } }

        it {
          expect(gql_errors.first[:message]).to eq('DemarcheDescriptor not found')
          expect(gql_errors.first[:extensions]).to eq({ code: 'not_found' })
        }
      end

      context 'find by id' do
        let(:variables) { { demarche: { id: procedure.to_typed_id } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheDescriptor][:id]).to eq(procedure.to_typed_id)
        }
      end

      context 'not opendata' do
        let(:variables) { { demarche: { id: procedure.to_typed_id } } }

        before { procedure.update(opendata: false) }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheDescriptor][:id]).to eq(procedure.to_typed_id)
        }
      end

      context 'without authorization token' do
        let(:authorization_header) { nil }

        context 'opendata' do
          let(:variables) { { demarche: { id: procedure.to_typed_id } } }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:demarcheDescriptor][:id]).to eq(procedure.to_typed_id)
          }
        end

        context 'not opendata' do
          let(:variables) { { demarche: { id: procedure.to_typed_id } } }

          before { procedure.update(opendata: false) }

          it {
            expect(gql_errors).not_to be_nil
            expect(gql_errors.first[:message]).to eq('An object of type DemarcheDescriptor was hidden due to permissions')
          }
        end
      end
    end
  end

  describe 'ds-mutation-v2' do
    let(:query_id) { 'ds-mutation-v2' }
    let(:disableNotification) { nil }

    context 'not found operation name' do
      let(:operation_name) { 'dossierStuff' }

      it {
        expect(gql_errors.first[:message]).to eq('No operation named "dossierStuff"')
      }
    end

    context 'dossierArchiver' do
      let(:dossier) { create(:dossier, :refuse, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id } } }
      let(:operation_name) { 'dossierArchiver' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierArchiver][:errors]).to be_nil
        expect(gql_data[:dossierArchiver][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierArchiver][:dossier][:archived]).to be_truthy
      }

      context 'read only token' do
        before { api_token.update(write_access: false) }

        it {
          expect(gql_data[:dossierArchiver][:errors].first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
        }
      end

      context 'when not processed' do
        let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }

        it {
          expect(gql_data[:dossierArchiver][:errors].first[:message]).to eq('Un dossier ne peut être déplacé dans « à archiver » qu’une fois le traitement terminé')
        }
      end
    end

    context 'dossierDesarchiver' do
      let(:dossier) { create(:dossier, :refuse, :with_individual, :archived, procedure:) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id } } }
      let(:operation_name) { 'dossierDesarchiver' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierDesarchiver][:errors]).to be_nil
        expect(gql_data[:dossierDesarchiver][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierDesarchiver][:dossier][:archived]).to be_falsey
      }

      context 'read only token' do
        before { api_token.update(write_access: false) }

        it {
          expect(gql_data[:dossierDesarchiver][:errors].first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
        }
      end

      context 'when not processed' do
        let(:dossier) { create(:dossier, :refuse, :with_individual, procedure:) }

        it {
          expect(gql_data[:dossierDesarchiver][:errors].first[:message]).to eq('Un dossier non archivé ne peut pas être désarchivé')
        }
      end
    end

    context 'dossierPasserEnInstruction' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, disableNotification: } } }
      let(:operation_name) { 'dossierPasserEnInstruction' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierPasserEnInstruction][:errors]).to be_nil
        expect(gql_data[:dossierPasserEnInstruction][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierPasserEnInstruction][:dossier][:state]).to eq('en_instruction')
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      }

      context 'without notifications' do
        let(:disableNotification) { true }

        it {
          expect(gql_errors).to be_nil
          perform_enqueued_jobs
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        }
      end

      context 'with pending corrections' do
        before { Flipper.enable(:blocking_pending_correction, dossier.procedure) }
        let!(:dossier_correction) { create(:dossier_correction, dossier:) }

        it {
          expect(dossier.pending_correction?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierPasserEnInstruction][:errors]).to eq([{ message: "Le dossier est en attente de correction" }])
        }
      end
    end

    context 'dossierRepasserEnConstruction' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, disableNotification: } } }
      let(:operation_name) { 'dossierRepasserEnConstruction' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierRepasserEnConstruction][:errors]).to be_nil
        expect(gql_data[:dossierRepasserEnConstruction][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierRepasserEnConstruction][:dossier][:state]).to eq('en_construction')
      }
    end

    context 'dossierRepasserEnInstruction' do
      let(:dossier) { create(:dossier, :refuse, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, disableNotification: } } }
      let(:operation_name) { 'dossierRepasserEnInstruction' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierRepasserEnInstruction][:errors]).to be_nil
        expect(gql_data[:dossierRepasserEnInstruction][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierRepasserEnInstruction][:dossier][:state]).to eq('en_instruction')
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      }

      context 'without notifications' do
        let(:disableNotification) { true }

        it {
          expect(gql_errors).to be_nil
          perform_enqueued_jobs
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        }
      end
    end

    context 'dossierAccepter' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, disableNotification: } } }
      let(:operation_name) { 'dossierAccepter' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierAccepter][:errors]).to be_nil
        expect(gql_data[:dossierAccepter][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierAccepter][:dossier][:state]).to eq('accepte')
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)

        expect(dossier.traitements.last.browser_name).to eq('api')
        expect(dossier.traitements.last.browser_version).to eq(2)
      }

      context 'without notifications' do
        let(:disableNotification) { true }

        it {
          expect(gql_errors).to be_nil
          perform_enqueued_jobs
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        }
      end

      context 'read only token' do
        before { api_token.update(write_access: false) }

        it {
          expect(gql_data[:dossierAccepter][:errors].first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
        }
      end

      context 'when already rejected' do
        let(:dossier) { create(:dossier, :refuse, :with_individual, procedure:) }

        it {
          expect(gql_data[:dossierAccepter][:errors].first[:message]).to eq('Le dossier est déjà refusé')
        }
      end

      context 'with entreprise' do
        let(:procedure) { create(:procedure, :published, :with_service, administrateurs: [admin]) }
        let(:dossier) { create(:dossier, :en_instruction, :with_entreprise, procedure:) }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAccepter][:errors]).to be_nil
          expect(gql_data[:dossierAccepter][:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossierAccepter][:dossier][:state]).to eq('accepte')
        }

        context 'when in degraded mode' do
          before { dossier.etablissement.update(adresse: nil) }

          it {
            expect(gql_data[:dossierAccepter][:errors].first[:message]).to eq('Les informations du SIRET du dossier ne sont pas complètes. Veuillez réessayer plus tard.')
          }
        end
      end
    end

    context 'dossierBasculeSuivi' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:follow) { true }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, follow: follow } } }

      let(:operation_name) { 'dossierBasculeSuivi' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierBasculeSuivi][:errors]).to be_nil
        expect(gql_data[:dossierBasculeSuivi][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierBasculeSuivi][:instructeur][:id]).to eq(instructeur.to_typed_id)
        expect(instructeur.followed_dossiers).to include(dossier)
      }

      context 'unfollow' do
        let(:follow) { false }

        before do
          instructeur.follow(dossier)
        end

        it {
          expect(gql_errors).to be_nil
          instructeur.reload
          expect(instructeur.followed_dossiers).to_not include(dossier)
        }
      end

      context 'read only token' do
        before { api_token.update(write_access: false) }

        it {
          expect(gql_data[:dossierBasculeSuivi][:errors].first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
        }
      end
    end

    context 'dossierRefuser' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, motivation: 'yolo', disableNotification: } } }
      let(:operation_name) { 'dossierRefuser' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierRefuser][:errors]).to be_nil
        expect(gql_data[:dossierRefuser][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierRefuser][:dossier][:state]).to eq('refuse')
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      }

      context 'without notifications' do
        let(:disableNotification) { true }

        it {
          expect(gql_errors).to be_nil
          perform_enqueued_jobs
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        }
      end

      context 'read only token' do
        before { api_token.update(write_access: false) }

        it {
          expect(gql_data[:dossierRefuser][:errors].first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
        }
      end

      context 'when already accepted' do
        let(:dossier) { create(:dossier, :accepte, :with_individual, procedure:) }

        it {
          expect(gql_data[:dossierRefuser][:errors].first[:message]).to eq('Le dossier est déjà accepté')
        }
      end

      context 'with entreprise' do
        let(:procedure) { create(:procedure, :published, :with_service, administrateurs: [admin]) }
        let(:dossier) { create(:dossier, :en_instruction, :with_entreprise, procedure:) }

        it '', :slow do
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierRefuser][:errors]).to be_nil
          expect(gql_data[:dossierRefuser][:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossierRefuser][:dossier][:state]).to eq('refuse')
        end

        context 'when in degraded mode' do
          before { dossier.etablissement.update(adresse: nil) }

          it '', :slow do
            expect(gql_data[:dossierRefuser][:errors].first[:message]).to eq('Les informations du SIRET du dossier ne sont pas complètes. Veuillez réessayer plus tard.')
          end
        end
      end
    end

    context 'dossierClasserSansSuite' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, motivation: 'yolo', disableNotification: } } }
      let(:operation_name) { 'dossierClasserSansSuite' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierClasserSansSuite][:errors]).to be_nil
        expect(gql_data[:dossierClasserSansSuite][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierClasserSansSuite][:dossier][:state]).to eq('sans_suite')
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      }

      context 'without notifications' do
        let(:disableNotification) { true }

        it {
          expect(gql_errors).to be_nil
          perform_enqueued_jobs
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        }
      end

      context 'read only token' do
        before { api_token.update(write_access: false) }

        it {
          expect(gql_data[:dossierClasserSansSuite][:errors].first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
        }
      end

      context 'when already accepted' do
        let(:dossier) { create(:dossier, :accepte, :with_individual, procedure:) }

        it {
          expect(gql_data[:dossierClasserSansSuite][:errors].first[:message]).to eq('Le dossier est déjà accepté')
        }
      end

      context 'with entreprise' do
        let(:procedure) { create(:procedure, :published, :with_service, administrateurs: [admin]) }
        let(:dossier) { create(:dossier, :en_instruction, :with_entreprise, procedure:) }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierClasserSansSuite][:errors]).to be_nil
          expect(gql_data[:dossierClasserSansSuite][:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossierClasserSansSuite][:dossier][:state]).to eq('sans_suite')
        }

        context 'when in degraded mode' do
          before { dossier.etablissement.update(adresse: nil) }

          it {
            expect(gql_data[:dossierClasserSansSuite][:errors].first[:message]).to eq('Les informations du SIRET du dossier ne sont pas complètes. Veuillez réessayer plus tard.')
          }
        end
      end
    end

    context 'groupeInstructeurModifier' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:variables) { { input: { groupeInstructeurId: dossier.groupe_instructeur.to_typed_id, label: 'nouveau groupe instructeur' } } }
      let(:operation_name) { 'groupeInstructeurModifier' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:groupeInstructeurModifier][:errors]).to be_nil
        expect(gql_data[:groupeInstructeurModifier][:groupeInstructeur][:id]).to eq(dossier.groupe_instructeur.to_typed_id)
        expect(dossier.groupe_instructeur.reload.label).to eq('nouveau groupe instructeur')
      }

      context 'close groupe instructeur' do
        let(:variables) { { input: { groupeInstructeurId: dossier.groupe_instructeur.to_typed_id, closed: true } } }

        context 'with multiple groupes' do
          let!(:defaut_groupe_instructeur) { create(:groupe_instructeur, procedure: procedure) }

          before { procedure.update(defaut_groupe_instructeur_id: defaut_groupe_instructeur.id) }

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:groupeInstructeurModifier][:errors]).to be_nil
            expect(gql_data[:groupeInstructeurModifier][:groupeInstructeur][:id]).to eq(dossier.groupe_instructeur.to_typed_id)
            expect(dossier.groupe_instructeur.reload.closed).to be_truthy
          }
        end

        context 'with api hack' do
          include Logic
          let(:types_de_champ_public) { [{ type: :drop_down_list }] }
          let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
          let(:routing_champ) { procedure.active_revision.types_de_champ.first }
          let!(:defaut_groupe_instructeur) { create(:groupe_instructeur, procedure: procedure) }

          before do
            groupe_instructeur.update(routing_rule: ds_eq(champ_value(routing_champ.stable_id), constant(groupe_instructeur.label)))
            procedure.update(defaut_groupe_instructeur_id: defaut_groupe_instructeur.id)
            Flipper.enable(:groupe_instructeur_api_hack, procedure)
          end

          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:groupeInstructeurModifier][:errors]).to be_nil
            expect(gql_data[:groupeInstructeurModifier][:groupeInstructeur][:id]).to eq(dossier.groupe_instructeur.to_typed_id)
            expect(routing_champ.reload.drop_down_options).to match_array(procedure.groupe_instructeurs.active.map(&:label))
            expect(procedure.groupe_instructeurs.active.map(&:routing_rule)).to match_array(procedure.groupe_instructeurs.active.map { ds_eq(champ_value(routing_champ.stable_id), constant(_1.label)) })
          }
        end

        context 'validation error' do
          it {
            expect(gql_errors).to be_nil
            expect(gql_data[:groupeInstructeurModifier][:errors].first[:message]).to eq('Il est impossible de désactiver le groupe d’instructeurs par défaut.')
          }
        end
      end
    end

    context 'groupeInstructeurCreer' do
      let(:variables) { { input: { demarche: { id: procedure.to_typed_id }, groupeInstructeur: { label: 'nouveau groupe instructeur' } }, includeInstructeurs: true } }
      let(:operation_name) { 'groupeInstructeurCreer' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:groupeInstructeurCreer][:errors]).to be_nil
        expect(gql_data[:groupeInstructeurCreer][:groupeInstructeur][:id]).not_to be_nil
        expect(gql_data[:groupeInstructeurCreer][:groupeInstructeur][:instructeurs]).to eq([{ id: admin.instructeur.to_typed_id, email: admin.email }])
        expect(GroupeInstructeur.last.label).to eq('nouveau groupe instructeur')
      }

      context 'with instructeurs' do
        let(:email) { 'test@test.com' }
        let(:variables) { { input: { demarche: { id: procedure.to_typed_id }, groupeInstructeur: { label: 'nouveau groupe instructeur avec instructeurs', instructeurs: [email:] } }, includeInstructeurs: true } }
        let(:operation_name) { 'groupeInstructeurCreer' }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:groupeInstructeurCreer][:errors]).to be_nil
          expect(gql_data[:groupeInstructeurCreer][:groupeInstructeur][:id]).not_to be_nil
          expect(gql_data[:groupeInstructeurCreer][:groupeInstructeur][:instructeurs]).to match_array([{ id: admin.instructeur.to_typed_id, email: admin.instructeur.email }, { id: Instructeur.last.to_typed_id, email: }])
        }
      end

      context 'with api hack' do
        include Logic
        let(:types_de_champ_public) { [{ type: :drop_down_list }] }
        let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
        let(:routing_champ) { procedure.active_revision.types_de_champ.first }

        before do
          groupe_instructeur.update(routing_rule: ds_eq(champ_value(routing_champ.stable_id), constant(groupe_instructeur.label)))
          Flipper.enable(:groupe_instructeur_api_hack, procedure)
        end

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:groupeInstructeurCreer][:errors]).to be_nil
          expect(gql_data[:groupeInstructeurCreer][:groupeInstructeur][:id]).not_to be_nil
          expect(routing_champ.reload.drop_down_options).to match_array(procedure.groupe_instructeurs.map(&:label))
          expect(procedure.groupe_instructeurs.map(&:routing_rule)).to match_array(procedure.groupe_instructeurs.map { ds_eq(champ_value(routing_champ.stable_id), constant(_1.label)) })
        }
      end
    end

    context 'groupeInstructeurAjouterInstructeurs' do
      let(:email) { 'test@test.com' }
      let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
      let(:existing_instructeur) { groupe_instructeur.instructeurs.first }
      let(:variables) { { input: { groupeInstructeurId: groupe_instructeur.to_typed_id, instructeurs: [{ email: }, { email: 'yolo' }, { id: existing_instructeur.to_typed_id }] }, includeInstructeurs: true } }
      let(:operation_name) { 'groupeInstructeurAjouterInstructeurs' }

      before do
        allow(GroupeInstructeurMailer).to receive(:notify_added_instructeurs)
          .and_return(double(deliver_later: true))
      end

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:groupeInstructeurAjouterInstructeurs][:errors]).to be_nil
        expect(gql_data[:groupeInstructeurAjouterInstructeurs][:warnings]).to eq([message: "yolo n’est pas une adresse électronique valide"])
        expect(gql_data[:groupeInstructeurAjouterInstructeurs][:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
        expect(groupe_instructeur.instructeurs.count).to eq(2)
        expect(gql_data[:groupeInstructeurAjouterInstructeurs][:groupeInstructeur][:instructeurs]).to match_array([{ id: existing_instructeur.to_typed_id, email: existing_instructeur.email }, { id: Instructeur.last.to_typed_id, email: }])
      }
    end

    context 'groupeInstructeurSupprimerInstructeurs' do
      let(:email) { 'test@test.com' }
      let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
      let(:existing_instructeur) { groupe_instructeur.instructeurs.first }
      let(:instructeur_2) { create(:instructeur) }
      let(:instructeur_3) { create(:instructeur) }
      let(:variables) { { input: { groupeInstructeurId: groupe_instructeur.to_typed_id, instructeurs: [{ email: }, { id: instructeur_2.to_typed_id }, { id: instructeur_3.to_typed_id }] }, includeInstructeurs: true } }
      let(:operation_name) { 'groupeInstructeurSupprimerInstructeurs' }

      before do
        allow(GroupeInstructeurMailer).to receive(:notify_removed_instructeur)
          .and_return(double(deliver_later: true))
        existing_instructeur
        groupe_instructeur.add(instructeur_2)
        groupe_instructeur.add(instructeur_3)
      end

      it {
        expect(groupe_instructeur.reload.instructeurs.count).to eq(3)
        expect(gql_errors).to be_nil
        expect(gql_data[:groupeInstructeurSupprimerInstructeurs][:errors]).to be_nil
        expect(gql_data[:groupeInstructeurSupprimerInstructeurs][:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
        expect(groupe_instructeur.instructeurs.count).to eq(1)
        expect(gql_data[:groupeInstructeurSupprimerInstructeurs][:groupeInstructeur][:instructeurs]).to eq([{ id: existing_instructeur.to_typed_id, email: existing_instructeur.email }])
        expect(GroupeInstructeurMailer).to have_received(:notify_removed_instructeur).twice
      }
    end

    context 'demarcheCloner' do
      let(:operation_name) { 'demarcheCloner' }

      context 'find by number' do
        let(:variables) { { input: { demarche: { number: procedure.id } } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheCloner][:errors]).to be_nil
          expect(gql_data[:demarcheCloner][:demarche][:id]).not_to be_nil
          expect(gql_data[:demarcheCloner][:demarche][:id]).not_to eq(procedure.to_typed_id)
          expect(gql_data[:demarcheCloner][:demarche][:id]).to eq(Procedure.last.to_typed_id)
        }
      end

      context 'find by id' do
        let(:variables) { { input: { demarche: { id: procedure.to_typed_id } } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheCloner][:errors]).to be_nil
          expect(gql_data[:demarcheCloner][:demarche][:id]).not_to be_nil
          expect(gql_data[:demarcheCloner][:demarche][:id]).not_to eq(procedure.to_typed_id)
          expect(gql_data[:demarcheCloner][:demarche][:id]).to eq(Procedure.last.to_typed_id)
        }
      end

      context 'with title' do
        let(:variables) { { input: { demarche: { id: procedure.to_typed_id }, title: new_title } } }
        let(:new_title) { "#{procedure.libelle} TEST 1" }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheCloner][:errors]).to be_nil
          expect(gql_data[:demarcheCloner][:demarche][:id]).to eq(Procedure.last.to_typed_id)
          expect(Procedure.last.libelle).to eq(new_title)
        }
      end
    end

    context 'dossierEnvoyerMessage' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: 'Hello World!' } } }
      let(:operation_name) { 'dossierEnvoyerMessage' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierEnvoyerMessage][:errors]).to be_nil
        expect(gql_data[:dossierEnvoyerMessage][:message][:id]).to eq(dossier.commentaires.first.to_typed_id)
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      }
    end

    context 'dossierSupprimerMessage' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
      let(:message) { create(:commentaire, dossier:, instructeur:) }
      let(:variables) { { input: { messageId: message.to_typed_id, instructeurId: instructeur.to_typed_id } } }
      let(:operation_name) { 'dossierSupprimerMessage' }

      it {
        expect(message.discarded?).to be_falsey
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierSupprimerMessage][:errors]).to be_nil
        expect(gql_data[:dossierSupprimerMessage][:message][:id]).to eq(message.to_typed_id)
        expect(gql_data[:dossierSupprimerMessage][:message][:discardedAt]).not_to be_nil
        expect(message.reload.discarded?).to be_truthy
      }

      context 'with cancelled correction' do
        let(:dossier_correction) { create(:dossier_correction, dossier:, commentaire: message, cancelled_at: Time.current) }

        it {
          expect(message.discarded?).to be_falsey
          expect(dossier_correction.commentaire.discarded?).to be_falsey
          expect(dossier_correction.cancelled?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:errors]).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:message][:id]).to eq(message.to_typed_id)
          expect(gql_data[:dossierSupprimerMessage][:message][:discardedAt]).not_to be_nil
          expect(message.reload.discarded?).to be_truthy
        }
      end

      context 'with pending correction' do
        let(:dossier_correction) { create(:dossier_correction, dossier:, commentaire: message) }

        it {
          expect(message.discarded?).to be_falsey
          expect(dossier_correction.commentaire.discarded?).to be_falsey
          expect(dossier.pending_correction?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:errors]).to eq([{ message: "Le message ne peut pas être supprimé" }])
          expect(message.reload.discarded?).to be_falsey
          expect(dossier_correction.reload.pending?).to be_truthy
        }
      end

      context 'when unauthorized' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: create(:procedure, :new_administrateur, :for_individual)) }

        it {
          expect(message.discarded?).to be_falsey
          expect(gql_errors.first[:message]).to eq("An object of type Message was hidden due to permissions")
        }
      end

      context 'when from not the same instructeur' do
        let(:other_instructeur) { create(:instructeur, followed_dossiers: dossiers) }
        let(:variables) { { input: { messageId: message.to_typed_id, instructeurId: other_instructeur.to_typed_id } } }

        it {
          expect(message.discarded?).to be_falsey
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:errors]).to eq([{ message: "Le message ne peut pas être supprimé" }])
        }
      end

      context 'when from usager' do
        let(:message) { create(:commentaire, dossier:) }

        it {
          expect(message.discarded?).to be_falsey
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:errors]).to eq([{ message: "Le message ne peut pas être supprimé" }])
        }
      end
    end

    context 'dossierAnnulerDemandeCorrection' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
      let(:message) { create(:commentaire, dossier:, instructeur:) }
      let(:dossier_correction) { create(:dossier_correction, dossier:, commentaire: message) }
      let(:variables) { { input: { messageId: message.to_typed_id, instructeurId: instructeur.to_typed_id } } }
      let(:operation_name) { 'dossierAnnulerDemandeCorrection' }

      it {
        expect(dossier_correction.pending?).to be_truthy
        expect(message.discarded?).to be_falsey
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierAnnulerDemandeCorrection][:errors]).to be_nil
        expect(gql_data[:dossierAnnulerDemandeCorrection][:message][:id]).to eq(message.to_typed_id)
        expect(dossier_correction.reload.cancelled?).to be_truthy
        expect(message.reload.discarded?).to be_falsey
      }

      context 'when no pending correction' do
        let(:message) { create(:commentaire, dossier:, instructeur:) }

        it {
          expect(message.dossier_correction).to be_nil
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAnnulerDemandeCorrection][:errors]).to eq([{ message: "La demande de correction ne peut pas être annulée" }])
        }
      end

      context 'when correction already cancelled' do
        let(:dossier_correction) { create(:dossier_correction, dossier:, commentaire: message, cancelled_at: Time.current) }

        it {
          expect(dossier_correction.cancelled?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAnnulerDemandeCorrection][:errors]).to eq([{ message: "La demande de correction ne peut pas être annulée" }])
        }
      end

      context 'when unauthorized' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: create(:procedure, :new_administrateur, :for_individual)) }

        it {
          expect(gql_errors.first[:message]).to eq("An object of type Message was hidden due to permissions")
        }
      end

      context 'when from another instructeur with access to the dossier' do
        let(:other_instructeur) { create(:instructeur, followed_dossiers: dossiers) }
        let(:variables) { { input: { messageId: message.to_typed_id, instructeurId: other_instructeur.to_typed_id } } }

        before { other_instructeur.assign_to_procedure(procedure) }

        it {
          expect(dossier_correction.pending?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAnnulerDemandeCorrection][:errors]).to be_nil
          expect(gql_data[:dossierAnnulerDemandeCorrection][:message][:id]).to eq(message.to_typed_id)
          expect(dossier_correction.reload.cancelled?).to be_truthy
        }
      end
    end
  end
end
