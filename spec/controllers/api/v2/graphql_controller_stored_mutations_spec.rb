# frozen_string_literal: true

describe API::V2::GraphqlController do
  let(:admin) { administrateurs.default }
  let(:generated_token) { APIToken.generate(admin) }
  let(:api_token) { generated_token.first }
  let(:token) { generated_token.second }
  let(:procedure) { procedures.individual }
  let(:dossier) { dossiers.en_construction }
  let(:instructeur) { instructeurs.default }
  let(:authorization_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

  before do
    instructeur.assign_to_procedure(procedure)
  end

  let(:query_id) { 'ds-mutation-v2' }
  let(:variables) { {} }
  let(:operation_name) { nil }
  let(:body) { JSON.parse(subject.body, symbolize_names: true) }
  let(:gql_data) { body[:data] }
  let(:gql_errors) { body[:errors] }

  subject { post :execute, params: { queryId: query_id, variables: variables, operationName: operation_name }.compact, as: :json }

  before do
    request.env['HTTP_AUTHORIZATION'] = authorization_header
  end

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

  describe 'ds-mutation-v2' do
    let(:disableNotification) { nil }

    context 'not found operation name' do
      let(:operation_name) { 'dossierStuff' }

      it {
        expect(gql_errors.first[:message]).to eq('No operation named "dossierStuff"')
      }
    end

    context 'dossierArchiver' do
      let(:dossier) { dossiers.refuse }
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
        let(:dossier) { dossiers.en_instruction }

        it {
          expect(gql_data[:dossierArchiver][:errors].first[:message]).to eq('Un dossier ne peut être déplacé dans « à archiver » qu’une fois le traitement terminé')
        }
      end
    end

    context 'dossierDesarchiver' do
      let(:dossier) { dossiers.refuse.tap { it.update(archived: true) } }
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

      context 'when not archived' do
        let(:dossier) { dossiers.refuse }

        it {
          expect(gql_data[:dossierDesarchiver][:errors].first[:message]).to eq('Un dossier non archivé ne peut pas être désarchivé')
        }
      end
    end

    context 'dossierPasserEnInstruction' do
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
      let(:dossier) { dossiers.en_instruction }
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
      let(:dossier) { dossiers.refuse }
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
      let(:dossier) { dossiers.en_instruction }
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

      context 'with motivation and justificatif' do
        let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, motivation: 'Parce que', justificatif: blob.signed_id } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAccepter][:errors]).to be_nil
          expect(gql_data[:dossierAccepter][:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossierAccepter][:dossier][:state]).to eq('accepte')
          expect(dossier.reload.motivation).to eq('Parce que')
          expect(dossier.justificatif_motivation).to be_attached
        }
      end

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
        let(:dossier) { dossiers.refuse }

        it {
          expect(gql_data[:dossierAccepter][:errors].first[:message]).to eq('Le dossier est déjà refusé')
        }
      end

      context 'with entreprise' do
        let(:procedure) { procedures.entreprise }
        let(:dossier) { dossiers.entreprise_en_instruction }

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
      let(:dossier) { dossiers.en_instruction }
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
      let(:dossier) { dossiers.en_instruction }
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

      context 'when attestation refus template is activated' do
        before do
          dossier.procedure.attestation_refus_template = build(:attestation_template, :refus, activated: true)
          dossier.procedure.save!
        end

        it 'should enqueue attestation job' do
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierRefuser][:errors]).to be_nil
          expect(gql_data[:dossierRefuser][:dossier][:state]).to eq('refuse')
          expect(AttestationPdfGenerationJob).to have_been_enqueued.with(dossier)
        end
      end

      context 'when attestation refus template is not activated' do
        before do
          dossier.procedure.attestation_refus_template = build(:attestation_template, :refus, activated: false)
          dossier.procedure.save!
        end

        it 'should not enqueue attestation generation job' do
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierRefuser][:errors]).to be_nil
          expect(gql_data[:dossierRefuser][:dossier][:state]).to eq('refuse')
          expect(AttestationPdfGenerationJob).not_to have_been_enqueued.with(dossier)
        end
      end

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
        let(:dossier) { dossiers.accepte }

        it {
          expect(gql_data[:dossierRefuser][:errors].first[:message]).to eq('Le dossier est déjà accepté')
        }
      end

      context 'with entreprise' do
        let(:procedure) { procedures.entreprise }
        let(:dossier) { dossiers.entreprise_en_instruction }

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
      let(:dossier) { dossiers.en_instruction }
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
        let(:dossier) { dossiers.accepte }

        it {
          expect(gql_data[:dossierClasserSansSuite][:errors].first[:message]).to eq('Le dossier est déjà accepté')
        }
      end

      context 'with entreprise' do
        let(:procedure) { procedures.entreprise }
        let(:dossier) { dossiers.entreprise_en_instruction }

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
      let(:dossier) { dossiers.en_instruction }
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
          let(:procedure) { create(:procedure, :published, :for_individual, administrateurs: [admin], types_de_champ_public: [{ type: :drop_down_list }]) }
          # created eagerly so the dossier belongs to the original defaut groupe,
          # not to defaut_groupe_instructeur which becomes the defaut below
          let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }
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

      context 'when the token is not scoped to the target procedure' do
        let(:other_procedure) { create(:procedure, :published, administrateurs: [admin]) }
        let(:variables) { { input: { demarche: { id: other_procedure.to_typed_id }, groupeInstructeur: { label: 'groupe hors périmètre', instructeurs: [{ email: 'attacker@evil.com' }] } }, includeInstructeurs: true } }

        # Token targeted to `procedure` only; `other_procedure` is owned by the same
        # admin but out of the token's scope.
        before { api_token.update(allowed_procedure_ids: [procedure.id]) }

        it 'refuses to create the groupe instructeur and does not add the instructeur' do
          expect(gql_data[:groupeInstructeurCreer][:groupeInstructeur]).to be_nil
          expect(gql_data[:groupeInstructeurCreer][:errors]).to be_present
          expect(other_procedure.groupe_instructeurs.count).to eq(1)
          expect(Instructeur.joins(:user).where(users: { email: 'attacker@evil.com' })).to be_empty
        end
      end

      context 'with api hack' do
        include Logic
        let(:procedure) { create(:procedure, :published, :for_individual, administrateurs: [admin], types_de_champ_public: [{ type: :drop_down_list }]) }
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

      context 'with cloneService: true' do
        let(:variables) { { input: { demarche: { id: procedure.to_typed_id }, cloneService: true } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheCloner][:errors]).to be_nil
          expect(Procedure.last.service).to eq(procedure.service)
        }
      end

      context 'without cloneService' do
        let(:variables) { { input: { demarche: { id: procedure.to_typed_id } } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:demarcheCloner][:errors]).to be_nil
          expect(Procedure.last.service).to be_nil
        }
      end
    end

    context 'dossierChangerGroupeInstructeur' do
      let(:variables) { { input: { dossierId: dossier.to_typed_id, groupeInstructeurId: groupe_instructeur.to_typed_id } } }
      let(:operation_name) { 'dossierChangerGroupeInstructeur' }

      context 'with a new groupe instructeur' do
        let(:groupe_instructeur) { create(:groupe_instructeur, label: 'new groupe instructeur', procedure:) }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierChangerGroupeInstructeur][:errors]).to be_nil
          expect(gql_data[:dossierChangerGroupeInstructeur][:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossierChangerGroupeInstructeur][:dossier][:groupeInstructeur][:id]).to eq(groupe_instructeur.to_typed_id)
          expect(dossier.reload.groupe_instructeur).to eq(groupe_instructeur)
        }
      end

      context 'when the dossier is already in the groupe instructeur' do
        let(:groupe_instructeur) { dossier.groupe_instructeur }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierChangerGroupeInstructeur][:dossier]).to be_nil
          expect(gql_data[:dossierChangerGroupeInstructeur][:errors]).to eq([{ message: "Le dossier est déjà avec le groupe instructeur: 'défaut'" }])
        }
      end
    end

    context 'dossierAjouterLabel' do
      let(:label) { create(:label, procedure:) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, labelId: label.to_typed_id } } }
      let(:operation_name) { 'dossierAjouterLabel' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierAjouterLabel][:errors]).to be_nil
        expect(gql_data[:dossierAjouterLabel][:dossier][:id]).to eq(dossier.to_typed_id)
        expect(gql_data[:dossierAjouterLabel][:dossier][:labels]).to eq([{ id: label.to_typed_id, name: label.name, color: label.color }])
        expect(gql_data[:dossierAjouterLabel][:label]).to eq(id: label.to_typed_id, name: label.name, color: label.color)
        expect(dossier.labels).to match_array([label])
      }

      context 'when label belongs to another procedure' do
        let(:label) { create(:label) }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAjouterLabel][:dossier]).to be_nil
          expect(gql_data[:dossierAjouterLabel][:errors]).to eq([{ message: "Ce label n’appartient pas à la même démarche que le dossier" }])
        }
      end

      context 'when label is already associated' do
        before { dossier.labels << label }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierAjouterLabel][:dossier]).to be_nil
          expect(gql_data[:dossierAjouterLabel][:errors]).to eq([{ message: "Ce label est déjà associé au dossier" }])
        }
      end
    end

    context 'dossierSupprimerLabel' do
      let(:label) { create(:label, procedure:) }
      let(:variables) { { input: { dossierId: dossier.to_typed_id, labelId: label.to_typed_id } } }
      let(:operation_name) { 'dossierSupprimerLabel' }

      context 'success' do
        before { dossier.labels << label }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerLabel][:errors]).to be_nil
          expect(gql_data[:dossierSupprimerLabel][:dossier][:id]).to eq(dossier.to_typed_id)
          expect(gql_data[:dossierSupprimerLabel][:dossier][:labels]).to eq([])
          expect(gql_data[:dossierSupprimerLabel][:label]).to eq(id: label.to_typed_id, name: label.name, color: label.color)
          expect(dossier.reload.labels).to be_empty
        }
      end

      context 'when label is not associated' do
        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerLabel][:dossier]).to be_nil
          expect(gql_data[:dossierSupprimerLabel][:errors]).to eq([{ message: "Ce label n’est pas associé au dossier" }])
        }
      end
    end

    context 'dossierEnvoyerMessage' do
      let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: 'Hello World!' } } }
      let(:operation_name) { 'dossierEnvoyerMessage' }

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierEnvoyerMessage][:errors]).to be_nil
        expect(gql_data[:dossierEnvoyerMessage][:message][:id]).to eq(dossier.commentaires.last.to_typed_id)
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      }

      context 'with attachment' do
        let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: 'Hello World!', attachment: blob.signed_id } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:errors]).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:message][:id]).to eq(dossier.commentaires.last.to_typed_id)
          expect(dossier.commentaires.last.piece_jointe).to be_attached
        }
      end

      context 'with correction' do
        let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: 'Hello World!', correction: 'incorrect' } } }

        it 'creates a correction and notifies the user' do
          expect { subject }.to have_enqueued_mail(DossierMailer, :notify_pending_correction)

          expect(gql_errors).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:errors]).to be_nil
          expect(dossier).to be_pending_correction
          expect(dossier.pending_correction).to be_dossier_incorrect
          expect(dossier.pending_correction.commentaire.body).to eq('Hello World!')
        end
      end

      context 'schema error' do
        let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id } } }

        it {
          expect(gql_data).to be_nil
          expect(gql_errors.first[:message]).to eq("Variable $input of type DossierEnvoyerMessageInput! was provided invalid value for body (Expected value to not be null)")
          expect(gql_errors.first.key?(:backtrace)).to be_falsey
        }
      end

      context 'variables error' do
        let(:variables) { "{" }

        it {
          expect(gql_data).to be_nil
          expect(gql_errors.first[:message]).to eq("expected object key, got EOF at line 1 column 2")
          expect(gql_errors.first.key?(:backtrace)).to be_falsey
        }
      end

      context 'validation error' do
        let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: '' } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:message]).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:errors]).to eq([{ message: "Le champ « Votre message » ne peut être vide" }])
        }
      end

      context 'upload error' do
        let(:variables) { { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: 'Hello World!', attachment: 'fake' } } }

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:message]).to be_nil
          expect(gql_data[:dossierEnvoyerMessage][:errors]).to eq([{ message: "L’identifiant du fichier téléversé est invalide" }])
        }
      end
    end

    context 'createDirectUpload' do
      let(:variables) do
        {
          input: {
            dossierId: dossier.to_typed_id,
            filename: blob_info[:filename],
            byteSize: blob_info[:byte_size],
            checksum: blob_info[:checksum],
            contentType: blob_info[:content_type],
          },
        }
      end
      let(:operation_name) { 'createDirectUpload' }
      let(:direct_upload_data) { gql_data[:createDirectUpload][:directUpload] }
      let(:direct_upload_blob) { ActiveStorage::Blob.find_signed(direct_upload_data[:signedBlobId]) }

      it "should initiate a direct upload" do
        expect(gql_errors).to be_nil
        expect(direct_upload_data[:url]).not_to be_nil
        expect(direct_upload_data[:headers]).not_to be_nil
        expect(direct_upload_data[:signedBlobId]).not_to be_nil
      end

      context "with a read-only token" do
        before { api_token.update(write_access: false) }

        it "returns an unauthorized error instead of a null violation (RAILS-MAY)" do
          expect(gql_data[:createDirectUpload]).to be_nil
          expect(gql_errors.first[:message]).to eq('Le jeton utilisé est configuré seulement en lecture')
          expect(gql_errors.first[:extensions][:code]).to eq('unauthorized')
        end
      end

      context "when the s3_storage feature is enabled on the procedure" do
        before { Flipper.enable(:s3_storage, procedure) }

        it "creates the blob on the amazon service" do
          expect(direct_upload_blob.service_name).to eq("amazon")
        end
      end

      context "when the uploaded content does not match the checksum" do
        let(:attach_exec) do
          post :execute, params: {
            queryId: query_id,
            operationName: 'dossierEnvoyerMessage',
            variables: { input: { dossierId: dossier.to_typed_id, instructeurId: instructeur.to_typed_id, body: 'Hello World!', attachment: direct_upload_data[:signedBlobId] } },
          }, as: :json
        end
        let(:attach_body) { JSON.parse(attach_exec.body, symbolize_names: true) }

        it "wrong hash error" do
          direct_upload_blob.service.upload(direct_upload_blob.key, StringIO.new('toto'))
          expect(attach_body[:data][:dossierEnvoyerMessage]).to eq(message: nil, errors: [{ message: "Le hash du fichier téléversé est invalide" }])
        end
      end
    end

    context 'dossierModifierAnnotations' do
      let(:procedure) { create(:procedure, :published, :for_individual, administrateurs: [admin], types_de_champ_private:) }
      let(:types_de_champ_private) { [{ type: :text }, { type: :checkbox }, { type: :integer_number }, { type: :decimal_number }, { type: :date }] }
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
      let(:annotations) { dossier.root_private_champs }
      let(:date) { 1.day.from_now.to_date.iso8601 }
      let(:operation_name) { 'dossierModifierAnnotations' }
      let(:variables) do
        {
          input: {
            dossierId: dossier.to_typed_id,
            instructeurId: instructeur.to_typed_id,
            annotations: [
              { id: annotations.first.to_typed_id, value: { text: 'hello' } },
              { id: annotations.second.to_typed_id, value: { checkbox: true } },
              { id: annotations.third.to_typed_id, value: { integerNumber: 42 } },
              { id: annotations.fourth.to_typed_id, value: { decimalNumber: 42.1 } },
              { id: annotations.fifth.to_typed_id, value: { date: } },
            ],
          },
        }
      end

      it {
        expect(gql_errors).to be_nil
        expect(gql_data[:dossierModifierAnnotations][:errors]).to be_nil
        expect(gql_data[:dossierModifierAnnotations][:annotations].map { _1[:id] }).to match_array(annotations.map(&:to_typed_id))
        expect(dossier.reload.root_private_champs.map(&:value)).to eq(['hello', 'true', '42', '42.1', date])
      }

      context 'with a value of the wrong type' do
        let(:variables) do
          {
            input: {
              dossierId: dossier.to_typed_id,
              instructeurId: instructeur.to_typed_id,
              annotations: [{ id: annotations.first.to_typed_id, value: { checkbox: true } }],
            },
          }
        end

        it {
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierModifierAnnotations][:annotations]).to eq([])
          expect(gql_data[:dossierModifierAnnotations][:errors]).to eq([{ message: "L‘annotation \"#{annotations.first.to_typed_id}\" n’est pas de type attendu" }])
        }
      end
    end

    context 'dossierSupprimerMessage' do
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

      context 'with pending correction and cancel_correction: true (default)' do
        let!(:dossier_correction) { create(:dossier_correction, dossier:, commentaire: message) }

        it 'cancels correction and deletes message' do
          expect(message.discarded?).to be_falsey
          expect(dossier_correction.pending?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:errors]).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:message][:discardedAt]).not_to be_nil
          expect(message.reload.discarded?).to be_truthy
          expect(dossier_correction.reload.cancelled?).to be_truthy
        end
      end

      context 'with pending correction and cancel_correction: false' do
        let!(:dossier_correction) { create(:dossier_correction, dossier:, commentaire: message) }
        let(:variables) { { input: { messageId: message.to_typed_id, instructeurId: instructeur.to_typed_id, cancelCorrection: false } } }

        it 'returns error and does not delete' do
          expect(message.discarded?).to be_falsey
          expect(dossier_correction.pending?).to be_truthy
          expect(gql_errors).to be_nil
          expect(gql_data[:dossierSupprimerMessage][:errors]).to eq([{ message: "Le message ne peut pas être supprimé" }])
          expect(message.reload.discarded?).to be_falsey
          expect(dossier_correction.reload.pending?).to be_truthy
        end
      end

      context 'when unauthorized' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: create(:procedure, :new_administrateur, :for_individual)) }

        it {
          expect(message.discarded?).to be_falsey
          expect(gql_errors.first[:message]).to eq("An object of type Message was hidden due to permissions")
        }
      end

      context 'when from not the same instructeur' do
        let(:other_instructeur) { create(:instructeur, followed_dossiers: [dossier]) }
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
        let(:other_instructeur) { create(:instructeur, followed_dossiers: [dossier]) }
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
