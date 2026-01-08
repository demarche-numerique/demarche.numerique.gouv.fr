# frozen_string_literal: true

describe API::V2::GraphqlController do
  let(:admin) { administrateurs(:default_admin) }
  let(:generated_token) { APIToken.generate(admin) }
  let(:api_token) { generated_token.first }
  let(:token) { generated_token.second }
  let(:types_de_champ_public) { [] }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service, administrateurs: [admin], types_de_champ_public:) }
  let(:dossier)  { create(:dossier, :en_construction, :with_individual, :with_populated_champs, procedure:) }
  let(:dossier1) { create(:dossier, :en_construction, :with_individual, procedure:, en_construction_at: 1.day.ago) }
  let(:dossier2) { create(:dossier, :en_construction, :with_individual, :archived, procedure:, en_construction_at: 3.days.ago) }
  let(:dossiers) { [dossier] }
  let(:instructeur) { create(:instructeur, followed_dossiers: dossiers) }

  def compute_checksum_in_chunks(io)
    Digest::MD5.new.tap do |checksum|
      while (chunk = io.read(5.megabytes))
        checksum << chunk
      end

      io.rewind
    end.base64digest
  end

  let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
  let(:blob_info) do
    {
      filename: file.original_filename,
      byte_size: file.size,
      checksum: compute_checksum_in_chunks(file),
      content_type: file.content_type,
      # we don't want to run virus scanner on this file
      metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE },
    }
  end
  let(:blob) do
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_info)
    blob.upload(file)
    blob
  end

  before { instructeur.assign_to_procedure(procedure) }

  let(:query) do
    "{
      demarche(number: #{procedure.id}) {
        id
        number
        title
        description
        state
        dateCreation
        dateDerniereModification
        dateFermeture
        groupeInstructeurs {
          label
          instructeurs {
            email
          }
        }
        revisions {
          id
        }
        draftRevision {
          id
        }
        publishedRevision {
          id
          champDescriptors {
            __typename
          }
        }
        service {
          nom
          typeOrganisme
          organisme
        }
        champDescriptors {
          __typename
          id
          label
          description
          required
          ... on RepetitionChampDescriptor {
            champDescriptors {
              __typename
              id
            }
          }
          ... on DropDownListChampDescriptor {
            options
          }
          ... on MultipleDropDownListChampDescriptor {
            options
          }
          ... on LinkedDropDownListChampDescriptor {
            options
          }
        }
        dossiers {
          nodes {
            id
          }
        }
        labels {
          id
          color
          name
        }
      }
    }"
  end
  let(:variables) { {} }
  let(:operation_name) { nil }
  let(:query_id) { nil }
  let(:body) { JSON.parse(subject.body, symbolize_names: true) }
  let(:gql_data) { body[:data] }
  let(:gql_errors) { body[:errors] }

  subject { post :execute, params: { query: query, variables: variables, operationName: operation_name, queryId: query_id }.compact, as: :json }

  context "when authenticated" do
    let(:authorization_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

    before do
      request.env['HTTP_AUTHORIZATION'] = authorization_header
    end

    describe "token authentication" do
      describe 'logging' do
        it "generates correct LogRage payload" do
          @rs = nil
          expect(controller).to receive(:request_logs).and_wrap_original do |m, *args|
            @rs = m.call(*args)
          end
          gql_data
          expect(@rs[:user_id]).to eq(admin.user.id)
          expect(@rs[:user_roles]).to eq("User, Instructeur, Administrateur")
        end
      end

      it {
        expect(gql_errors).to eq(nil)
        expect(gql_data).not_to be_nil
      }

      context "when the token is invalid" do
        before do
          request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials('invalid')
        end

        it {
          expect(gql_errors.first[:message]).to eq("Without a token, only persisted queries are allowed")
        }
      end

      context "when the token does not belong to an admin of the procedure" do
        let(:another_administrateur) { create(:administrateur) }
        let(:token_v3) { APIToken.generate(another_administrateur)[1] }
        let(:plain_token) { APIToken.send(:unpack, token_v3)[:plain_token] }
        before do
          request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(token)
        end

        context 'v3' do
          let(:token) { token_v3 }
          it {
            expect(gql_errors.first[:message]).to eq("An object of type Demarche was hidden due to permissions")
          }
        end
      end

      context "when the token is revoked" do
        before do
          admin.api_tokens.destroy_all
        end

        it {
          expect(token).not_to be_nil
          expect(gql_errors.first[:message]).to eq("Without a token, only persisted queries are allowed")
        }
      end

      context 'when procedure is not selected' do
        let(:other_procedure) { create(:procedure, administrateurs: [admin]) }
        before { api_token.update(allowed_procedure_ids: [other_procedure.id]) }

        it {
          expect(gql_errors.first[:message]).to eq("An object of type Demarche was hidden due to permissions")
        }
      end
    end

    describe "demarche" do
      describe "query a demarche" do
        let(:label) { build(:label) }
        let(:procedure) {
          create(:procedure, :published, :for_individual, :with_service, :with_all_champs, :with_all_annotations, administrateurs: [admin], labels: [label])
        }

        def format_type_champ(type_champ)
          "#{type_champ.gsub('regions', 'region').gsub('departements', 'departement').gsub('communes', 'commune').camelcase}ChampDescriptor"
        end

        it "returns the demarche", :slow do
          expect(gql_errors).to eq(nil)
          expect(gql_data).to include(demarche: {
            id: procedure.to_typed_id,
            number: procedure.id,
            title: procedure.libelle,
            description: procedure.description,
            state: 'publiee',
            dateFermeture: nil,
            dateCreation: procedure.created_at.iso8601,
            dateDerniereModification: procedure.updated_at.iso8601,
            groupeInstructeurs: [
              {
                instructeurs: [{ email: instructeur.email }],
                label: "défaut",
              },
            ],
            revisions: procedure.revisions.map { { id: _1.to_typed_id } },
            draftRevision: { id: procedure.draft_revision.to_typed_id },
            publishedRevision: {
              id: procedure.published_revision.to_typed_id,
              champDescriptors: procedure.published_revision.types_de_champ_public.map { { __typename: format_type_champ(_1.type_champ) } },
            },
            service: {
              nom: procedure.service.nom,
              typeOrganisme: procedure.service.type_organisme,
              organisme: procedure.service.organisme,
            },
            champDescriptors: procedure.active_revision.types_de_champ_public.map do |tdc|
              {
                id: tdc.to_typed_id,
                label: tdc.libelle,
                __typename: format_type_champ(tdc.type_champ),
                description: tdc.description,
                required: tdc.mandatory?,
                champDescriptors: tdc.repetition? ? procedure.active_revision.children_of(tdc.reload).map { { id: _1.to_typed_id, __typename: format_type_champ(_1.type_champ) } } : nil,
                options: tdc.any_drop_down_list? ? tdc.drop_down_options.reject(&:empty?) : nil,
              }.compact
            end,
            dossiers: {
              nodes: dossiers.map { { id: _1.to_typed_id } },
            },
            labels: [{ id: label.to_typed_id, color: label.color, name: label.name }],
          })
        end
      end

      describe "filter dossiers" do
        let(:dossiers) { [dossier, dossier1, dossier2] }

        let(:query) do
          "{
            demarche(number: #{procedure.id}) {
              id
              number
              dossiers(createdSince: \"#{2.days.ago.iso8601}\") {
                nodes {
                  id
                }
              }
            }
          }"
        end

        it "should be returned" do
          expect(gql_errors).to eq(nil)
          expect(gql_data).to eq(demarche: {
            id: procedure.to_typed_id,
            number: procedure.id,
            dossiers: {
              nodes: [{ id: dossier1.to_typed_id }, { id: dossier.to_typed_id }],
            },
          })
        end
      end

      describe "filter archived dossiers" do
        let(:dossiers) { [dossier, dossier1, dossier2] }
        let(:query) do
          "{
            demarche(number: #{procedure.id}) {
              id
              number
              dossiers(archived: #{archived_filter}) {
                nodes {
                  id
                }
              }
            }
          }"
        end

        context 'with archived=true' do
          let(:archived_filter) { 'true' }

          it 'returns only archived dossiers' do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(demarche: {
              id: procedure.to_typed_id,
              number: procedure.id,
              dossiers: {
                nodes: [{ id: dossier2.to_typed_id }],
              },
            })
          end
        end

        context 'with archived=false' do
          let(:archived_filter) { 'false' }

          it 'returns only non-archived dossiers' do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(demarche: {
              id: procedure.to_typed_id,
              number: procedure.id,
              dossiers: {
                nodes: [{ id: dossier1.to_typed_id }, { id: dossier.to_typed_id }],
              },
            })
          end
        end
      end

      describe "filter by minRevision" do
        let(:query) do
          "{
            demarche(number: #{procedure.id}) {
              id
              number
              dossiers(minRevision: \"#{procedure.revisions.first.to_typed_id}\") {
                nodes {
                  id
                }
              }
            }
          }"
        end

        it "should be returned" do
          expect(gql_errors).to eq(nil)
          expect(gql_data).to eq(demarche: {
            id: procedure.to_typed_id,
            number: procedure.id,
            dossiers: {
              nodes: procedure.dossiers.order(:created_at).map do |dossier|
                { id: dossier.to_typed_id }
              end,
            },
          })
        end
      end

      describe "filter by maxRevision" do
        let(:query) do
          "{
            demarche(number: #{procedure.id}) {
              id
              number
              dossiers(maxRevision: \"#{procedure.revisions.last.to_typed_id}\") {
                nodes {
                  id
                }
              }
            }
          }"
        end

        it "should be returned" do
          expect(gql_errors).to eq(nil)
          expect(gql_data).to eq(demarche: {
            id: procedure.to_typed_id,
            number: procedure.id,
            dossiers: {
              nodes: procedure.dossiers.order(:created_at).map do |dossier|
                { id: dossier.to_typed_id }
              end,
            },
          })
        end
      end
    end

    describe "dossier" do
      let(:dossier) do
        dossier = create(:dossier,
                         :en_construction,
                         :with_populated_champs,
                         :with_populated_annotations,
                         :with_individual,
                         procedure: procedure)
        create(:commentaire, :with_file, dossier: dossier, email: 'test@test.com')
        dossier
      end

      context "for individual" do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, :with_all_champs, :with_all_annotations, administrateurs: [admin]) }
        let(:query) do
          "{
            dossier(number: #{dossier.id}) {
              id
              number
              state
              dateDerniereModification
              datePassageEnConstruction
              datePassageEnInstruction
              dateTraitement
              dateDepot
              motivation
              motivationAttachment {
                url
              }
              demarche {
                number
                title
                state
              }
              usager {
                id
                email
              }
              demandeur {
                id
                ... on PersonnePhysique {
                  nom
                  prenom
                  civilite
                  dateDeNaissance
                }
              }
              instructeurs {
                id
                email
              }
              groupeInstructeur {
                id
                number
                label
              }
              revision {
                id
                champDescriptors {
                  type
                }
              }
              messages {
                email
                body
                attachment {
                  filename
                  checksum
                  byteSize
                  contentType
                  virusScanResult
                }
                attachments {
                  filename
                  checksum
                  byteSize
                  contentType
                  virusScanResult
                }
              }
              avis {
                expert {
                  email
                }
                question
                reponse
                dateQuestion
                dateReponse
                attachment {
                  url
                  filename
                }
              }
              champs {
                id
                label
                stringValue
              }
            }
          }"
        end

        it "should be returned", :slow do
          expect(gql_errors).to eq(nil)
          expect(gql_data[:dossier]).to include(
            id: dossier.to_typed_id,
            number: dossier.id,
            state: 'en_construction',
            dateDerniereModification: dossier.updated_at.iso8601,
            datePassageEnConstruction: dossier.en_construction_at.iso8601,
            dateDepot: dossier.depose_at.iso8601,
            datePassageEnInstruction: nil,
            dateTraitement: nil,
            motivation: nil,
            motivationAttachment: nil,
            demarche: {
              number: dossier.procedure.id,
              title: dossier.procedure.libelle,
              state: 'publiee',
            },
            usager: {
              id: dossier.user.to_typed_id,
              email: dossier.user.email,
            },
            instructeurs: [
              {
                id: instructeur.to_typed_id,
                email: instructeur.email,
              },
            ],
            groupeInstructeur: {
              id: dossier.groupe_instructeur.to_typed_id,
              number: dossier.groupe_instructeur.id,
              label: dossier.groupe_instructeur.label,
            },
            revision: {
              id: dossier.revision.to_typed_id,
              champDescriptors: dossier.types_de_champ_public.map do |tdc|
                {
                  type: tdc.type_champ,
                }
              end,
            },
            demandeur: {
              id: dossier.individual.to_typed_id,
              nom: dossier.individual.nom,
              prenom: dossier.individual.prenom,
              civilite: 'M',
              dateDeNaissance: '1991-11-01',
            },
            avis: []
          )

          expected_champs = dossier.project_champs_public.map do |champ|
            {
              id: champ.to_typed_id,
              label: champ.libelle,
              stringValue: champ.type_de_champ.champ_value_for_api(champ),
            }
          end
          expect(gql_data[:dossier][:champs]).to match_array(expected_champs)

          expected_messages = dossier.commentaires.map do |commentaire|
            {
              body: commentaire.body,
              attachment: {
                filename: commentaire.piece_jointe.first.filename.to_s,
                contentType: commentaire.piece_jointe.first.content_type,
                checksum: commentaire.piece_jointe.first.checksum,
                byteSize: commentaire.piece_jointe.first.byte_size,
                virusScanResult: commentaire.piece_jointe.first.virus_scan_result,
              },
              attachments: commentaire.piece_jointe.map do |pj|
                {
                  filename: pj.filename.to_s,
                  contentType: pj.content_type,
                  checksum: pj.checksum,
                  byteSize: pj.byte_size,
                  virusScanResult: pj.virus_scan_result,
                }
              end,
              email: commentaire.email,
            }
          end
          expect(gql_data[:dossier][:messages]).to match_array(expected_messages)

          expect(gql_data[:dossier][:champs][0][:id]).to eq(dossier.project_champs_public[0].type_de_champ.to_typed_id)
        end
      end

      context "for entreprise" do
        let(:procedure_for_entreprise) { create(:procedure, :published, administrateurs: [admin]) }
        let(:dossier) { create(:dossier, :en_construction, :with_entreprise, procedure: procedure_for_entreprise) }

        let(:query) do
          "{
            dossier(number: #{dossier.id}) {
              id
              number
              usager {
                id
                email
              }
              demandeur {
                id
                ... on PersonneMorale {
                  siret
                  siegeSocial
                  numeroVoie
                  typeVoie
                  entreprise {
                    siren
                    dateCreation
                    capitalSocial
                    codeEffectifEntreprise
                    numeroTvaIntracommunautaire
                  }
                }
              }
            }
          }"
        end

        context "in the nominal case" do
          it "should be returned" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossier: {
              id: dossier.to_typed_id,
              number: dossier.id,
              usager: {
                id: dossier.user.to_typed_id,
                email: dossier.user.email,
              },
              demandeur: {
                id: dossier.etablissement.to_typed_id,
                siret: dossier.etablissement.siret,
                siegeSocial: dossier.etablissement.siege_social,
                numeroVoie: dossier.etablissement.numero_voie.to_s,
                typeVoie: dossier.etablissement.type_voie.to_s,
                entreprise: {
                  siren: dossier.etablissement.entreprise_siren,
                  dateCreation: dossier.etablissement.entreprise_date_creation.iso8601,
                  capitalSocial: dossier.etablissement.entreprise_capital_social.to_s,
                  codeEffectifEntreprise: dossier.etablissement.entreprise_code_effectif_entreprise.to_s,
                  numeroTvaIntracommunautaire: dossier.etablissement.entreprise_numero_tva_intracommunautaire,
                },
              },
            })
          end
        end

        context "with links" do
          let(:dossier) { create(:dossier, :accepte, :with_attestation_acceptation, procedure: procedure) }
          let(:query) do
            "{
              dossier(number: #{dossier.id}) {
                id
                number
                pdf {
                  url
                }
                geojson {
                  url
                }
                attestation {
                  url
                }
              }
            }"
          end

          it "urls should be returned" do
            expect(gql_errors).to eq(nil)

            expect(gql_data[:dossier][:pdf][:url]).not_to be_nil
            expect(gql_data[:dossier][:geojson][:url]).not_to be_nil
            expect(gql_data[:dossier][:attestation][:url]).not_to be_nil
          end
        end

        context "when there are missing data" do
          before do
            dossier.etablissement.update!(entreprise_code_effectif_entreprise: nil, entreprise_capital_social: nil,
                                          numero_voie: nil, type_voie: nil, entreprise_numero_tva_intracommunautaire: nil)
          end

          it "should be returned" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossier: {
              id: dossier.to_typed_id,
              number: dossier.id,
              usager: {
                id: dossier.user.to_typed_id,
                email: dossier.user.email,
              },
              demandeur: {
                id: dossier.etablissement.to_typed_id,
                siret: dossier.etablissement.siret,
                siegeSocial: dossier.etablissement.siege_social,
                numeroVoie: nil,
                typeVoie: nil,
                entreprise: {
                  siren: dossier.etablissement.entreprise_siren,
                  dateCreation: dossier.etablissement.entreprise_date_creation.iso8601,
                  capitalSocial: '-1',
                  codeEffectifEntreprise: nil,
                  numeroTvaIntracommunautaire: nil,
                },
              },
            })
          end
        end

        context "error in degraded mode" do
          before do
            dossier.etablissement.update!(adresse: nil, siege_social: nil)
          end

          it "should return an error" do
            expect(gql_errors.first).to include({ message: "Cannot return null for non-nullable field PersonneMorale.siegeSocial", extensions: { code: "invalid_null" } })
          end
        end
      end

      context "champs" do
        let(:procedure) { create(:procedure, :published, :for_individual, administrateurs: [admin], types_de_champ_public: [{ type: :date }, { type: :datetime }]) }
        let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
        let(:champ_date) { dossier.project_champs_public.first }
        let(:champ_datetime) { dossier.project_champs_public.second }

        before do
          champ_date.update(value: '2019-07-10')
          champ_datetime.update(value: '15/09/1962 15:35')
        end

        context "with Date" do
          let(:query) do
            "{
              dossier(number: #{dossier.id}) {
                champs {
                  id
                  label
                  ... on DateChamp {
                    value
                  }
                }
              }
            }"
          end

          it "should be returned" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossier: {
              champs: [
                {
                  id: champ_date.to_typed_id,
                  label: champ_date.libelle,
                  value: '2019-07-10T00:00:00+02:00',
                },
                {
                  id: champ_datetime.to_typed_id,
                  label: champ_datetime.libelle,
                  value: '1962-09-15T15:35:00+01:00',
                },
              ],
            })
          end
        end

        context "with Datetime" do
          let(:query) do
            "{
              dossier(number: #{dossier.id}) {
                champs {
                  id
                  label
                  ... on DateChamp {
                    value
                    date
                  }
                  ... on DatetimeChamp {
                    datetime
                  }
                }
              }
            }"
          end

          it "should be returned" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossier: {
              champs: [
                {
                  id: champ_date.to_typed_id,
                  label: champ_date.libelle,
                  value: '2019-07-10T00:00:00+02:00',
                  date: '2019-07-10',
                },
                {
                  id: champ_datetime.to_typed_id,
                  label: champ_datetime.libelle,
                  datetime: '1962-09-15T15:35:00+01:00',
                },
              ],
            })
          end
        end
      end
    end

    describe "deletedDossiers" do
      let(:query) do
        "{
          demarche(number: #{procedure.id}) {
            deletedDossiers {
              nodes {
                id
                number
                state
                reason
                dateSupression
              }
            }
          }
        }"
      end
      let(:deleted_dossier) { create(:deleted_dossier, procedure: procedure) }

      before { deleted_dossier }

      it "should be returned" do
        expect(gql_errors).to eq(nil)
        expect(gql_data).to eq(demarche: {
          deletedDossiers: {
            nodes: [
              {
                id: deleted_dossier.to_typed_id,
                number: deleted_dossier.dossier_id,
                state: deleted_dossier.state,
                reason: deleted_dossier.reason,
                dateSupression: deleted_dossier.deleted_at.iso8601,
              },
            ],
          },
        })
      end
    end

    describe "champ piece_justificative" do
      let(:types_de_champ_public) { [{ type: :piece_justificative }] }
      let(:champ) { dossier.champs.first }
      let(:byte_size) { 2712286911 }

      context "with deprecated file field" do
        let(:query) do
          "{
            dossier(number: #{dossier.id}) {
              champs(id: \"#{champ.to_typed_id}\") {
                ... on PieceJustificativeChamp {
                  file { byteSize }
                }
              }
            }
          }"
        end

        it {
          expect(gql_errors).to be_nil
          expect(gql_data).to eq(dossier: { champs: [{ file: { byteSize: 4 } }] })
        }
      end

      context "byteSize" do
        let(:query) do
          "{
            dossier(number: #{dossier.id}) {
              champs(id: \"#{champ.to_typed_id}\") {
                ... on PieceJustificativeChamp {
                  files { byteSize }
                }
              }
            }
          }"
        end

        it {
          expect(gql_errors).to be_nil
          expect(gql_data).to eq(dossier: { champs: [{ files: [{ byteSize: 4 }] }] })
        }
      end

      context "virusScanResult" do
        let(:query) do
          "{
            dossier(number: #{dossier.id}) {
              champs(id: \"#{champ.to_typed_id}\") {
                ... on PieceJustificativeChamp {
                  files { virusScanResult }
                }
              }
            }
          }"
        end

        context "when virus scan is safe" do
          it {
            expect(gql_errors).to be_nil
            expect(gql_data).to eq(dossier: { champs: [{ files: [{ virusScanResult: 'safe' }] }] })
          }
        end

        context "when virus scan is pending" do
          before do
            champ.piece_justificative_file.first.blob.update(virus_scan_result: 'pending')
            champ.piece_justificative_file.first.blob.metadata.delete(:virus_scan_result)
          end

          it {
            expect(gql_errors).to be_nil
            expect(gql_data).to eq(dossier: { champs: [{ files: [{ virusScanResult: 'pending' }] }] })
          }
        end
      end

      context "when the file is really big" do
        before do
          champ.piece_justificative_file.first.blob.update(byte_size: byte_size)
        end

        context "byteSize" do
          let(:query) do
            "{
              dossier(number: #{dossier.id}) {
                champs(id: \"#{champ.to_typed_id}\") {
                  ... on PieceJustificativeChamp {
                    files { byteSize }
                  }
                }
              }
            }"
          end

          it {
            expect(gql_errors).not_to be_nil
          }
        end

        context "byteSizeBigInt" do
          let(:query) do
            "{
              dossier(number: #{dossier.id}) {
                champs(id: \"#{champ.to_typed_id}\") {
                  ... on PieceJustificativeChamp {
                    files { byteSizeBigInt }
                  }
                }
              }
            }"
          end

          it {
            expect(gql_errors).to be_nil
            expect(gql_data).to eq(dossier: { champs: [{ files: [{ byteSizeBigInt: '2712286911' }] }] })
          }
        end
      end
    end

    describe "groupeInstructeur" do
      let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
      let(:query) do
        "{
          groupeInstructeur(number: #{groupe_instructeur.id}) {
            id
            number
            label
            dossiers {
              nodes {
                id
              }
            }
          }
        }"
      end

      it "should be returned" do
        expect(gql_errors).to eq(nil)
        expect(gql_data).to eq(groupeInstructeur: {
          id: groupe_instructeur.to_typed_id,
          number: groupe_instructeur.id,
          label: groupe_instructeur.label,
          dossiers: {
            nodes: dossiers.map { |dossier| { id: dossier.to_typed_id } },
          },
        })
      end
    end

    describe "mutations" do
      describe 'dossierEnvoyerMessage' do
        let(:query) do
          "mutation($input: DossierEnvoyerMessageInput!) {
            dossierEnvoyerMessage(input: $input) {
              message {
                body
              }
              errors {
                message
              }
            }
          }"
        end
        let(:variables) { { input: input } }
        let(:input) do
          {
            dossierId: dossier_id,
            instructeurId: instructeur_id,
            body: input_body,
            attachment: attachment,
          }
        end
        let(:dossier_id) { dossier.to_typed_id }
        let(:instructeur_id) { instructeur.to_typed_id }
        let(:input_body) { "Bonjour" }
        let(:attachment) { nil }

        context 'success' do
          let(:attachment) { blob.signed_id }

          it "should post a message" do
            expect(gql_errors).to eq(nil)

            expect(gql_data).to eq(dossierEnvoyerMessage: {
              message: {
                body: "Bonjour",
              },
              errors: nil,
            })
          end
        end

        context 'with correction' do
          let(:input) { super().merge(correction: :incorrect) }

          it 'should create a correction' do
            expect(gql_data).to eq(dossierEnvoyerMessage: {
              message: {
                body: "Bonjour",
              },
              errors: nil,
            })

            expect(dossier).to be_pending_correction
            expect(dossier.pending_correction).to be_dossier_incorrect
            expect(dossier.pending_correction.commentaire.body).to eq("Bonjour")
          end
        end

        context 'schema error' do
          let(:input) do
            {
              dossierId: dossier_id,
              instructeurId: instructeur_id,
            }
          end

          it "should fail" do
            expect(gql_data).to eq(nil)
            expect(gql_errors).not_to eq(nil)
            expect(body[:errors].first[:message]).to eq("Variable $input of type DossierEnvoyerMessageInput! was provided invalid value for body (Expected value to not be null)")
            expect(body[:errors].first.key?(:backtrace)).to be_falsey
          end
        end

        context 'variables error' do
          let(:variables) { "{" }

          it "should fail" do
            expect(gql_data).to eq(nil)
            expect(gql_errors).not_to eq(nil)
            expect(body[:errors].first[:message]).to eq("expected object key, got EOF at line 1 column 2")
            expect(body[:errors].first.key?(:backtrace)).to be_falsey
          end
        end

        context 'validation error' do
          let(:input_body) { "" }

          it "should fail" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossierEnvoyerMessage: {
              errors: [{ message: "Le champ « Votre message » ne peut être vide" }],
              message: nil,
            })
          end
        end

        context 'upload error' do
          let(:attachment) { 'fake' }

          it "should fail" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossierEnvoyerMessage: {
              errors: [{ message: "L’identifiant du fichier téléversé est invalide" }],
              message: nil,
            })
          end
        end
      end

      describe 'dossierAccepter' do
        let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
        let(:query) do
          "mutation {
            dossierAccepter(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              instructeurId: \"#{instructeur.to_typed_id}\",
              motivation: \"Parce que\",
              justificatif: \"#{blob.signed_id}\"
            }) {
              dossier {
                id
                state
                motivation
              }
              errors {
                message
              }
            }
          }"
        end

        context 'success' do
          it "should accepter dossier" do
            expect(gql_errors).to eq(nil)

            expect(gql_data).to eq(dossierAccepter: {
              dossier: {
                id: dossier.to_typed_id,
                state: "accepte",
                motivation: "Parce que",
              },
              errors: nil,
            })
          end
        end

        context 'success without motivation' do
          let(:query) do
            "mutation {
              dossierAccepter(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\"
              }) {
                dossier {
                  id
                  state
                  motivation
                }
                errors {
                  message
                }
              }
            }"
          end

          it "should accepter dossier" do
            expect(gql_errors).to eq(nil)

            expect(gql_data).to eq(dossierAccepter: {
              dossier: {
                id: dossier.to_typed_id,
                state: "accepte",
                motivation: nil,
              },
              errors: nil,
            })
          end
        end

        context 'validation error' do
          let(:dossier) { create(:dossier, :refuse, :with_individual, procedure: procedure) }

          it "should fail" do
            expect(gql_errors).to eq(nil)
            expect(gql_data).to eq(dossierAccepter: {
              errors: [{ message: "Le dossier est déjà refusé" }],
              dossier: nil,
            })
          end
        end
      end

      describe 'dossierRefuser' do
        let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }
        let(:query) do
          "mutation {
          dossierRefuser(input: {
            dossierId: \"#{dossier.to_typed_id}\",
            instructeurId: \"#{instructeur.to_typed_id}\",
            motivation: \"Dossier incomplet\"
          }) {
            dossier {
              id
              state
              attestation {
                url
                filename
              }
            }
            errors {
              message
            }
          }
        }"
        end

        context 'when attestation refus template is activated' do
          before do
            dossier.procedure.attestation_refus_template = build(:attestation_template, :refus, activated: true)
            dossier.procedure.save!
          end

          it 'should enqueue attestation job' do
            expect(gql_errors).to eq(nil)
            expect(gql_data[:dossierRefuser][:dossier][:state]).to eq('refuse')
            expect(AttestationPdfGenerationJob).to have_been_enqueued.with(dossier)
            expect(gql_data[:dossierRefuser][:errors]).to be_nil
          end
        end

        context 'when attestation refus template is not activated' do
          before do
            dossier.procedure.attestation_refus_template = build(:attestation_template, :refus, activated: false)
            dossier.procedure.save!
          end

          it 'should not enqueue attestation generation job' do
            expect(gql_errors).to eq(nil)
            expect(gql_data[:dossierRefuser][:dossier][:state]).to eq('refuse')
            expect(AttestationPdfGenerationJob).not_to have_been_enqueued.with(dossier)
            expect(gql_data[:dossierRefuser][:errors]).to be_nil
          end
        end
      end

      describe 'createDirectUpload' do
        let(:query) do
          "mutation {
            createDirectUpload(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              filename: \"#{blob_info[:filename]}\",
              byteSize: #{blob_info[:byte_size]},
              checksum: \"#{blob_info[:checksum]}\",
              contentType: \"#{blob_info[:content_type]}\"
            }) {
              directUpload {
                url
                headers
                blobId
                signedBlobId
              }
            }
          }"
        end

        let(:attach_query) do
          "mutation {
            dossierEnvoyerMessage(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              instructeurId: \"#{instructeur.to_typed_id}\",
              body: \"Hello world\",
              attachment: \"#{direct_upload_blob_id}\"
            }) {
              message {
                body
              }
              errors {
                message
              }
            }
          }"
        end
        let(:attach_query_exec) { post :execute, params: { query: attach_query } }
        let(:attach_query_body) { JSON.parse(attach_query_exec.body, symbolize_names: true) }
        let(:attach_query_data) { attach_query_body[:data] }
        let(:direct_upload_data) { gql_data[:createDirectUpload][:directUpload] }
        let(:direct_upload_blob_id) { direct_upload_data[:signedBlobId] }

        it "should initiate a direct upload" do
          expect(gql_errors).to eq(nil)

          data = gql_data[:createDirectUpload][:directUpload]
          expect(data[:url]).not_to be_nil
          expect(data[:headers]).not_to be_nil
          expect(data[:blobId]).not_to be_nil
          expect(data[:signedBlobId]).not_to be_nil
        end

        it "wrong hash error" do
          blob = ActiveStorage::Blob.find direct_upload_data[:blobId]
          blob.service.upload blob.key, StringIO.new('toto')
          expect(attach_query_data).to eq(dossierEnvoyerMessage: {
            errors: [{ message: "Le hash du fichier téléversé est invalide" }],
            message: nil,
          })
        end
      end

      describe 'dossierChangerGroupeInstructeur' do
        let(:query) do
          "mutation {
            dossierChangerGroupeInstructeur(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              groupeInstructeurId: \"#{dossier.groupe_instructeur.to_typed_id}\"
            }) {
              errors {
                message
              }
            }
          }"
        end

        it "validation error" do
          expect(gql_errors).to eq(nil)

          expect(gql_data).to eq(dossierChangerGroupeInstructeur: {
            errors: [{ message: "Le dossier est déjà avec le groupe instructeur: 'défaut'" }],
          })
        end

        context "should changer groupe instructeur" do
          let!(:new_groupe_instructeur) { create(:groupe_instructeur, label: 'new groupe instructeur', procedure: procedure) }

          let(:query) do
            "mutation {
            dossierChangerGroupeInstructeur(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              groupeInstructeurId: \"#{new_groupe_instructeur.to_typed_id}\"
            }) {
              errors {
                message
              }
            }
          }"
          end

          it "change made" do
            expect(gql_errors).to eq(nil)

            expect(gql_data).to eq(dossierChangerGroupeInstructeur: {
              errors: nil,
            })
          end
        end
      end

      describe 'dossierModifierAnnotation' do
        let(:procedure) do
          create(:procedure, :published, :for_individual, :with_service, administrateurs: [admin], types_de_champ_private:)
        end

        describe 'text' do
          let(:types_de_champ_private) { [{ type: :text }] }

          let(:query) do
            "mutation {
              dossierModifierAnnotationText(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type == 'Champs::TextChamp' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: \"hello\"
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success" do
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationText: {
                annotation: {
                  stringValue: 'hello',
                },
                errors: nil,
              })
            end
          end
        end

        describe 'checkbox' do
          let(:types_de_champ_private) { [{ type: :checkbox }] }

          let(:value) { 'true' }

          let(:query) do
            "mutation {
              dossierModifierAnnotationCheckbox(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type_champ == 'checkbox' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: #{value}
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success when true" do
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationCheckbox: {
                annotation: {
                  stringValue: 'true',
                },
                errors: nil,
              })
            end
          end

          context "success when false" do
            let(:value) { 'false' }

            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationCheckbox: {
                annotation: {
                  stringValue: 'false',
                },
                errors: nil,
              })
            end
          end
        end

        describe 'yes_no' do
          let(:types_de_champ_private) { [{ type: :yes_no }] }
          let(:value) { 'true' }

          let(:query) do
            "mutation {
              dossierModifierAnnotationCheckbox(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type_champ == 'yes_no' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: #{value}
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success when true" do
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationCheckbox: {
                annotation: {
                  stringValue: 'true',
                },
                errors: nil,
              })
            end
          end

          context "success when false" do
            let(:value) { 'false' }

            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationCheckbox: {
                annotation: {
                  stringValue: 'false',
                },
                errors: nil,
              })
            end
          end
        end

        describe 'date' do
          let(:types_de_champ_private) { [{ type: :date }] }

          let(:query) do
            "mutation {
              dossierModifierAnnotationDate(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type_champ == 'date' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: \"#{1.day.from_now.to_date.iso8601}\"
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success" do
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationDate: {
                annotation: {
                  stringValue: dossier.reload.project_champs_private.find { |c| c.type_champ == 'date' }.to_s,
                },
                errors: nil,
              })
            end
          end
        end

        describe 'datetime' do
          let(:types_de_champ_private) { [{ type: :datetime }] }

          let(:query) do
            "mutation {
              dossierModifierAnnotationDatetime(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type_champ == 'datetime' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: \"#{1.day.from_now.iso8601}\"
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success" do
            let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationDatetime: {
                annotation: {
                  stringValue: dossier.reload.project_champs_private.find { |c| c.type_champ == 'datetime' }.to_s,
                },
                errors: nil,
              })
              expect(dossier.champs.first.value).not_to be_nil
            end
          end
        end

        describe 'drop_down_list' do
          let(:drop_down_options) { ['bijour'] }
          let(:types_de_champ_private) { [{ type: :drop_down_list, options: drop_down_options }] }
          let(:query) do
            "mutation {
              dossierModifierAnnotationDropDownList(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type_champ == 'drop_down_list' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: \"#{value}\"
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success" do
            let(:value) { drop_down_options.first }
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationDropDownList: {
                annotation: {
                  stringValue: dossier.reload.project_champs_private.find { |c| c.type_champ == 'drop_down_list' }.to_s,
                },
                errors: nil,
              })
            end
          end
          context "failure" do
            let(:value) { drop_down_options.first.reverse }
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationDropDownList: {
                annotation: nil,
                errors: [{ message: "doit être dans les options proposées" }],
              })
            end
          end
        end

        describe 'integer_number' do
          let(:types_de_champ_private) { [{ type: :integer_number }] }
          let(:query) do
            "mutation {
              dossierModifierAnnotationIntegerNumber(input: {
                dossierId: \"#{dossier.to_typed_id}\",
                annotationId: \"#{dossier.project_champs_private.find { |c| c.type_champ == 'integer_number' }.to_typed_id}\",
                instructeurId: \"#{instructeur.to_typed_id}\",
                value: 42
              }) {
                annotation {
                  stringValue
                }
                errors {
                  message
                }
              }
            }"
          end

          context "success" do
            it 'should be a success' do
              expect(gql_errors).to eq(nil)

              expect(gql_data).to eq(dossierModifierAnnotationIntegerNumber: {
                annotation: {
                  stringValue: '42',
                },
                errors: nil,
              })
            end
          end
        end
      end

      describe 'dossierAjouterLabel' do
        let(:label) { create(:label, procedure:) }
        let(:query) do
          "mutation {
            dossierAjouterLabel(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              labelId: \"#{label.to_typed_id}\"
            }) {
              dossier {
                id
                labels {
                  id
                  name
                  color
                }
              }
              errors {
                message
              }
            }
          }"
        end

        it "should add label to dossier" do
          expect(gql_errors).to eq(nil)
          expect(gql_data).to eq(dossierAjouterLabel: {
            dossier: {
              id: dossier.to_typed_id,
              labels: [
                {
                  id: label.to_typed_id,
                  name: label.name,
                  color: label.color,
                },
              ],
            },
            errors: nil,
          })

          expect(dossier.labels).to match_array([label])
        end

        context 'validations' do
          context "invalid label" do
            let(:label) { create(:label) }

            it "should return error" do
              expect(gql_data).to eq(dossierAjouterLabel: {
                dossier: nil,
                errors: [{ message: "Ce label n’appartient pas à la même démarche que le dossier" }],
              })
            end
          end

          context 'label already associated' do
            before { dossier.labels << label }
            it "should return an error" do
              expect(gql_data).to eq(dossierAjouterLabel: {
                dossier: nil,
                errors: [{ message: "Ce label est déjà associé au dossier" }],
              })
            end
          end
        end
      end
    end

    describe 'dossierSupprimerLabel' do
      let(:label) { create(:label, procedure:) }
      let(:query) do
        "mutation {
            dossierSupprimerLabel(input: {
              dossierId: \"#{dossier.to_typed_id}\",
              labelId: \"#{label.to_typed_id}\"
            }) {
              dossier {
                id
                labels {
                  id
                  name
                  color
                }
              }
              errors {
                message
              }
            }
          }"
      end

      context 'success' do
        before {
          dossier.labels << label
        }

        it "should remove label to dossier" do
          expect(gql_errors).to eq(nil)
          expect(gql_data).to eq(dossierSupprimerLabel: {
            dossier: {
              id: dossier.to_typed_id,
              labels: [],
            },
            errors: nil,
          })
        end
      end

      context 'label not associated' do
        it "should return an error" do
          expect(gql_data).to eq(dossierSupprimerLabel: {
            dossier: nil,
            errors: [{ message: "Ce label n’est pas associé au dossier" }],
          })
        end
      end
    end
  end
end
