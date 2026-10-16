# frozen_string_literal: true

describe AttachmentsController, type: :controller do
  let(:user) { create(:user) }
  let(:attachment) { champ.piece_justificative_file.attachments.first }
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, user:, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:user_buffer_champ) { dossier.champ_data.reload.find(&:user_buffer_stream?) }
  let(:signed_id) { attachment.blob.signed_id }

  describe '#destroy' do
    render_views

    let(:attachment) { champ.piece_justificative_file.attachments.first }
    let(:signed_id) { attachment.blob.signed_id }
    let(:view_as) { nil }

    subject do
      delete :destroy, params: { id: attachment.id, signed_id:, dossier_id: dossier&.id, stable_id: champ&.stable_id, view_as: }, format: :turbo_stream
    end

    context "when authenticated" do
      before { sign_in(user) }

      context 'and dossier is owned by user' do
        before { champ.update_columns(external_state: 'fetched', value_json:, data:) }

        context "when it is a champ with ocr data" do
          let(:value_json) { { ocr: 'some value' } }
          let(:data) { { ocr: 'some value' } }

          it 'removes the attachment, and resets the ocr data' do
            is_expected.to have_http_status(200)

            champ.reload

            expect(champ.piece_justificative_file.attached?).to be(false)
            expect(champ.external_state).to eq('idle')
            expect(champ.value_json).to be_nil
            expect(champ.data).to be_nil
          end
        end

        context 'when it is a france connect champ, with its replacement attachment' do
          let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :quotient_familial }]) }
          let(:dossier) { create(:dossier, user:, procedure:) }
          let(:data) {
            {
              api_part: {
                "quotient_familial": {
                  "valeur": 464,
                  "fournisseur": "CAF",
                  "mois": "12",
                  "annee": "2023",
                  "mois_calcul": "12",
                  "annee_calcul": "2023",
                },
              },
            }
          }
          let(:value_json) {
            {
              api_part: {
                "quotient_familial": {
                  "valeur": 464,
                  "periode_effective": "2023-12-01",
                  "fournisseur": "CAF",
                  "periode_calcul": "2023-12-01",
                },
              },
            }
          }

          before { champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png')) }

          it "does not resets data" do
            is_expected.to have_http_status(200)

            champ.reload

            expect(champ.piece_justificative_file.attached?).to be(false)
            expect(champ.external_state).to eq('fetched')
            expect(champ.value_json).not_to be_nil
            expect(champ.data).not_to be_nil
          end
        end
      end

      context 'and dossier en_construction is owned by user' do
        let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, user:, procedure:) }

        it 'removes the attachment and renders the footer with enabled submit button' do
          is_expected.to have_http_status(200)
          expect(user_buffer_champ.piece_justificative_file.attached?).to be(false)
          expect(response.body).to include('Déposer les modifications')
          expect(response.body).not_to include('disabled')
        end
      end

      context 'and the dossier can no longer be updated by the user' do
        let(:user) { users.usager }
        let(:type_de_champ) { dossier.revision.public_root_type_de_champs.find(&:piece_justificative?) }
        let(:champ) do
          dossier.champ_for_update(type_de_champ, updated_by: user.email).tap do
            it.piece_justificative_file.attach(io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf')
            it.save!
          end
        end

        [:en_instruction, :accepte].each do |state|
          context "when the dossier is #{state}" do
            let(:dossier) { dossiers.public_send(state) }

            it 'doesn’t remove the attachment' do
              is_expected.to have_http_status(404)
              expect(champ.reload.piece_justificative_file.attached?).to be(true)
            end
          end
        end
      end

      context 'and signed_id is invalid' do
        let(:signed_id) { 'yolo' }

        it 'doesn’t remove the attachment' do
          is_expected.to have_http_status(404)
          expect(champ.reload.piece_justificative_file.attached?).to be(true)
        end
      end
    end

    context 'as an administrateur' do
      let(:procedure) { create(:procedure, :with_logo) }
      let(:administrateur) { procedure.administrateurs.first }
      let(:attachment) { procedure.logo.attachments.first }
      let(:signed_id) { attachment.blob.signed_id }
      let(:view_as) { 'link' }
      before { sign_in(administrateur.user) }

      context 'when the administrateur owns the procedure' do
        it 'can remove the procedure attachment' do
          is_expected.to have_http_status(200)
          expect(procedure.reload.logo.attached?).to be(false)
        end

        context 'can remove an attestation template attachment' do
          let(:attestation_template) { create(:attestation_template, :with_files) }
          let(:procedure) { attestation_template.procedure }
          let(:attachment) { attestation_template.logo.attachments.first }
          let(:signed_id) { attachment.blob.signed_id }

          it do
            is_expected.to have_http_status(200)
            expect(attestation_template.reload.logo.attached?).to be(false)
          end
        end

        context 'can remove a type de champ notice explicative' do
          let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }
          let(:type_de_champ) { procedure.active_revision.type_de_champs.first }
          let(:attachment) { type_de_champ.notice_explicative.attachments.first }
          let(:signed_id) { attachment.blob.signed_id }

          before do
            type_de_champ.notice_explicative.attach({ io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Notice.pdf' })
          end

          it do
            is_expected.to have_http_status(200)
            expect(type_de_champ.reload.notice_explicative.attached?).to be(false)
          end
        end

        context 'can remove a groupe instructeur signature' do
          let(:procedure) { create(:procedure) }
          let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
          let(:attachment) { groupe_instructeur.signature.attachments.first }
          let(:signed_id) { attachment.blob.signed_id }

          before do
            groupe_instructeur.signature.attach(
              io: Rails.root.join('spec/fixtures/files/black.png').open,
              filename: 'signature.png',
              content_type: 'image/png'
            )
          end

          it do
            is_expected.to have_http_status(200)
            expect(groupe_instructeur.reload.signature.attached?).to be(false)
          end
        end
      end

      context 'when the administrateur does not own the procedure' do
        let(:administrateur) { create(:administrateur) }

        it 'can remove the procedure attachment' do
          is_expected.to have_http_status(404)
          expect(procedure.reload.logo.attached?).to be(true)
        end
      end
    end

    context 'for an avis' do
      let(:expert) { create(:expert) }
      let(:procedure) { create(:procedure) }
      let(:experts_procedure) { create(:experts_procedure, procedure:, expert:) }
      let(:avis) { create(:avis, :with_answer, dossier:, experts_procedure:) }
      let(:attachment) { avis.piece_justificative_file.attachments.first }
      let(:signed_id) { attachment.blob.signed_id }
      let(:view_as) { 'link' }

      before do
        avis.piece_justificative_file.attach({ io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf' })
      end

      context 'when the expert owns the avis' do
        before { sign_in(expert.user) }

        it 'can remove the attachment' do
          is_expected.to have_http_status(200)
          expect(avis.reload.piece_justificative_file.attached?).to be(false)
        end
      end

      context 'when the expert does not own the avis' do
        let(:other_expert) { experts.second }
        before { sign_in(other_expert.user) }

        it 'can’t remove the attachment' do
          is_expected.to have_http_status(404)
          expect(avis.reload.piece_justificative_file.attached?).to be(true)
        end
      end
    end

    context 'as an instructeur' do
      let(:instructeur) { create(:instructeur) }
      before { sign_in(instructeur.user) }

      context 'when the instructeur belongs to the procedure' do
        let(:procedure) { create(:procedure, instructeurs: [instructeur], private_type_de_champs: [{ type: :piece_justificative }]) }
        let(:dossier) { create(:dossier, :en_instruction, procedure:) }
        let(:champ) do
          dossier.champ_data.private_only.first.tap do |c|
            c.piece_justificative_file.attach({ io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf' })
          end
        end

        it 'remove the attachment' do
          is_expected.to have_http_status(200)
          expect(champ.reload.piece_justificative_file.attached?).to be(false)
        end
      end

      context 'can remove a groupe instructeur signature with self management enabled' do
        let(:procedure) { create(:procedure, instructeurs: [instructeur], instructeurs_self_management_enabled: true) }
        let(:groupe_instructeur) { procedure.defaut_groupe_instructeur }
        let(:attachment) { groupe_instructeur.signature.attachments.first }
        let(:signed_id) { attachment.blob.signed_id }
        let(:view_as) { 'link' }

        before do
          groupe_instructeur.signature.attach(
            io: Rails.root.join('spec/fixtures/files/black.png').open,
            filename: 'signature.png',
            content_type: 'image/png'
          )
        end

        it do
          is_expected.to have_http_status(200)
          expect(groupe_instructeur.reload.signature.attached?).to be(false)
        end
      end

      context 'cannot remove a groupe instructeur signature without self management' do
        let(:procedure) { create(:procedure, instructeurs: [instructeur], instructeurs_self_management_enabled: false) }
        let(:groupe_instructeur) { procedure.defaut_groupe_instructeur }
        let(:attachment) { groupe_instructeur.signature.attachments.first }
        let(:signed_id) { attachment.blob.signed_id }
        let(:view_as) { 'link' }

        before do
          groupe_instructeur.signature.attach(
            io: Rails.root.join('spec/fixtures/files/black.png').open,
            filename: 'signature.png',
            content_type: 'image/png'
          )
        end

        it do
          is_expected.to have_http_status(404)
          expect(groupe_instructeur.reload.signature.attached?).to be(true)
        end
      end
    end

    context 'when authenticated as another user' do
      let(:other_user) { create(:user) }
      before { sign_in(other_user) }

      it 'doesn’t remove the attachment' do
        is_expected.to have_http_status(404)
        expect(champ.reload.piece_justificative_file.attached?).to be(true)
      end

      context 'when trying to delete an attachment which is not a champ' do
        let(:procedure) { create(:procedure, :with_logo, public_type_de_champs: [{ type: :text }]) }
        let(:attachment) { procedure.logo.attachments.first }
        let(:signed_id) { attachment.blob.signed_id }

        it 'doesn’t remove the attachment' do
          is_expected.to have_http_status(404)
          expect(attachment.reload).to be_present
        end
      end
    end

    context 'when not authenticated' do
      it 'doesn’t remove the attachment' do
        is_expected.to redirect_to(new_user_session_path)
        expect(champ.reload.piece_justificative_file.attached?).to be(true)
      end
    end
  end

  describe '#destroy in a repetition with min items edited in the user buffer stream' do
    include Logic
    render_views

    let(:procedure) do
      children = [
        { type: :drop_down_list, libelle: 'type', stable_id: 901, mandatory: false, options: ['oui', 'non'] },
        { type: :text, libelle: 'detail', stable_id: 902, mandatory: true, condition: ds_eq(champ_value(901), constant('oui')) },
        { type: :piece_justificative, libelle: 'pj', stable_id: 903, mandatory: false },
      ]
      create(:procedure, :published, public_type_de_champs: [{ type: :repetition, mandatory: true, libelle: 'bloc', stable_id: 900, children: }])
        .tap { it.active_revision.public_root_type_de_champs.first.update!(limit_repetitions: '1', min_repetitions: '1') }
    end
    let(:dossier) { create(:dossier, user:, procedure:) }
    let(:repetition_type_de_champ) { procedure.active_revision.public_root_type_de_champs.first }
    let(:children) { procedure.active_revision.children_of(repetition_type_de_champ) }
    let(:row_id) { dossier.repetition_row_ids(repetition_type_de_champ).first }
    let(:attachment) { ActiveStorage::Attachment.find_by(record_id: buffered_pj.id) }
    let(:buffered_pj) do
      dossier.champ_for_update(children.first, row_id:, updated_by: user.email).update!(value: 'non')
      dossier.champ_for_update(children.second, row_id:, updated_by: user.email).update!(value: 'x')
      dossier.update_columns(state: 'en_construction', en_construction_at: Time.zone.now, depose_at: Time.zone.now)
      buffered = DossierPreloader.load_one(Dossier.find(dossier.id))
      buffered.with_update_stream(user)
      buffered.champ_for_update(children.first, row_id:, updated_by: user.email).update!(value: 'oui')
      buffered.champ_for_update(children.second, row_id:, updated_by: user.email).update!(value: '')
      buffered.champ_for_update(children.third, row_id:, updated_by: user.email).tap do
        it.piece_justificative_file.attach(io: StringIO.new('toto'), filename: 'toto.txt', content_type: 'text/plain')
        it.save!
      end
    end

    before { sign_in(user) }

    it 'evaluates the block on the buffer stream, where the row misses a mandatory value' do
      delete :destroy, params: { id: attachment.id, signed_id: attachment.blob.signed_id }, format: :turbo_stream

      expect(response).to have_http_status(200)
      expect(response.body).not_to include('repetition:limits-respected')
    end
  end
end
