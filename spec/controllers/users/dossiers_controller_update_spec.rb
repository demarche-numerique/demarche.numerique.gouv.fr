# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users.usager }

  describe '#submit_en_construction (stream)' do
    let(:owner) { create(:user) }
    let(:procedure_traits) { [] }
    let(:dossier_traits) { [] }
    let(:procedure) { create(:procedure, :for_individual, :published, *procedure_traits, public_type_de_champs:) }
    let(:public_type_de_champs) { [{ type: :text, mandatory: false }] }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, *dossier_traits, procedure:, user: owner).tap { _1.with_update_stream(_1.user) } }
    let(:now) { Time.zone.parse('01/01/2100') }
    let(:params) { { id: dossier.id } }
    let(:champs) { dossier.root_champs_public }
    let(:make_changes) do
      champ = champs.first
      if champ.present?
        champ_for_update(champ).update(value: 'beautiful value')
      end
    end

    subject do
      make_changes
      travel_to(now) { post :submit_en_construction, params: }
    end

    context 'when the owner signs in' do
      before { sign_in(owner) }

      context 'when the dossier cannot be updated by the owner' do
        let(:dossier) { create(:dossier, :en_instruction, user: owner) }

        it 'redirects to the dossiers list' do
          subject

          expect(response).to redirect_to(dossier_path(dossier))
          expect(flash.alert).to eq('Votre dossier ne peut plus être modifié')
        end
      end

      context 'when dossier is ready for submit' do
        it 'does not raise any errors' do
          subject

          expect(response).to redirect_to(dossier_path(dossier))
        end
      end

      context 'when the update fails' do
        render_views

        before do
          allow_any_instance_of(Dossier).to receive(:validate).and_return(false)
          allow_any_instance_of(Dossier).to receive(:errors).and_return(
            [double(base: champs.first, attribute: :value, message: 'nop')]
          )

          subject
        end

        it { expect(response).to render_template(:modifier) }
      end

      context 'when dossier has no changes' do
        let(:make_changes) {}

        it 'redirects to the dossier' do
          subject

          expect(response).to redirect_to(dossier_path(dossier))
          expect(flash.alert).to eq("Les modifications ont déjà été déposées")
        end
      end

      context 'when a mandatory champ is missing' do
        render_views
        let(:public_type_de_champs) { [{}, { type: :text, mandatory: true, libelle: 'l' }] }
        let(:empty_champ) { champs.second }

        before { subject }

        it do
          expect(response).to render_template(:modifier)
          expect(response.body).to have_content("doit être rempli")
          expect(response.body).not_to have_content("et doit être rempli")
          expect(response.body).to have_link(empty_champ.libelle, href: "##{empty_champ.focusable_input_id}")
        end
      end

      context 'when dossier repetition had been removed in newer version' do
        let(:public_type_de_champs) { [{}, { type: :repetition, libelle: 'repetition', children: [{ type: :text, libelle: 'child' }] }] }
        let(:dossier_traits) { [:with_populated_champs] }
        let(:champ_repetition) { champs.find(&:repetition?) }

        before do
          procedure.draft_revision.remove_type_de_champ(champ_repetition.stable_id)
          procedure.publish_revision!(procedure.administrateurs.first)

          champ_repetition.dossier.reload
          champ_repetition.dossier.rebase!
        end

        it { expect { subject }.not_to raise_error }
      end

      context "with pending correction" do
        let(:correction) { create(:dossier_correction, dossier:) }

        context "on simple procedure" do
          before { correction }

          it 'resolves correction automatically' do
            expect { subject }.to change { correction.reload.resolved_at }.to be_truthy
          end
        end

        context 'and sva enabled' do
          let(:procedure_traits) { [:sva] }
          let(:pending_correction) { "1" }
          let(:now) { Time.current }
          let(:params) { { id: dossier.id, dossier: { pending_correction: } } }

          before { correction }

          context 'when resolving correction' do
            it 'passe automatiquement en instruction' do
              expect(dossier.pending_correction?).to be_truthy

              subject
              dossier.reload

              expect(dossier).to be_en_instruction
              expect(dossier.pending_correction?).to be_falsey
              expect(dossier.en_instruction_at).to within(5.seconds).of(Time.current)
            end
          end

          context 'when not resolving correction' do
            render_views
            let(:pending_correction) { "" }

            it 'does not passe automatiquement en instruction' do
              subject
              dossier.reload

              expect(dossier).to be_en_construction
              expect(dossier.pending_correction?).to be_truthy

              expect(response.body).to include("Cochez la case")
            end
          end
        end
      end
    end

    context 'when a invite signs in' do
      let(:invite_user) { create(:user) }
      let!(:invite) { create(:invite, dossier:, user: invite_user) }

      before { sign_in(invite_user) }
      context 'and the invite tries to submit the dossier' do
        before { subject }

        it do
          expect(response).to redirect_to(root_path)
          expect(flash.alert).to include("Vous n’avez pas accès à ce dossier")
        end
      end
    end

    context 'when owner logged via france connect' do
      before do
        sign_in(owner)
        owner.update!(loged_in_with_france_connect: 'particulier')
      end

      it 'sets submitted_with_france_connect to true' do
        subject
        dossier.reload
        expect(dossier.submitted_with_france_connect).to be true
      end
    end

    context 'when owner not logged via france connect' do
      before do
        sign_in(owner)
        owner.update!(loged_in_with_france_connect: nil)
        dossier.update!(submitted_with_france_connect: true)
      end

      it 'sets submitted_with_france_connect to false' do
        subject
        dossier.reload
        expect(dossier.submitted_with_france_connect).to be false
      end
    end
  end

  describe '#update en_construction (stream)' do
    before { sign_in(user) }

    let(:public_type_de_champs) { [{}, { type: :piece_justificative }] }
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let!(:dossier) { create(:dossier, :en_construction, user:, procedure:) }
    let(:first_champ) { dossier.root_champs_public.first }
    let(:first_champ_user_buffer) { dossier.with_update_stream(dossier.user) { dossier.root_champs_public.first } }
    let(:piece_justificative_champ) { dossier.root_champs_public.last }
    let(:piece_justificative_champ_user_buffer) { dossier.with_update_stream(dossier.user) { dossier.root_champs_public.last } }
    let(:value) { 'beautiful value' }
    let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
    let(:now) { Time.zone.parse('01/01/2100') }

    let(:submit_payload) do
      {
        id: dossier.id,
        dossier: { champs_public_attributes: },
      }
    end
    let(:champs_public_attributes) do
      {
        first_champ.public_id => { value: value },
      }
    end
    let(:payload) { submit_payload }

    subject do
      travel_to(now) do
        patch :update, params: payload, format: :turbo_stream
      end
    end

    context 'when the dossier cannot be updated by the user' do
      let!(:dossier) { create(:dossier, :en_instruction, user:, procedure:) }

      it 'redirects to the dossiers list' do
        subject
        expect(response).to redirect_to(dossier_path(dossier))
        expect(flash.alert).to eq('Votre dossier ne peut plus être modifié')
      end
    end

    context 'when champ is pre_rempli (read-only guard)' do
      let(:public_type_de_champs) { [{ type: :pre_rempli }] }
      let(:pre_rempli_champ) { dossier.root_champs_public.first }

      before { pre_rempli_champ.update_column(:value, 'original') }

      let(:champs_public_attributes) do
        { pre_rempli_champ.public_id => { value: 'forged' } }
      end

      it 'ignores the update (early return)' do
        subject
        expect(pre_rempli_champ.reload.value).to eq('original')
      end
    end

    context 'when dossier can be updated by the owner' do
      it 'updates the champs' do
        subject
        dossier.reload
        expect(dossier.user_buffer_changes?).to be_truthy
        expect(first_champ_user_buffer.stream).to eq(Dossier::USER_BUFFER_STREAM)
        expect(first_champ_user_buffer.value).to eq('beautiful value')
        expect(first_champ_user_buffer.updated_at).to eq(now)
      end

      context 'updates the pj' do
        let(:champs_public_attributes) do
          {
            piece_justificative_champ.public_id => { piece_justificative_file: file },
          }
        end

        it do
          subject
          dossier.reload
          expect(dossier.user_buffer_changes?).to be_truthy
          expect(piece_justificative_champ_user_buffer.stream).to eq(Dossier::USER_BUFFER_STREAM)
          expect(piece_justificative_champ_user_buffer.piece_justificative_file).to be_attached
        end
      end

      it 'does not update the dossier timestamps' do
        subject
        dossier.reload
        expect(dossier.updated_at).not_to eq(now)
        expect(dossier.last_champ_updated_at).to be_nil
      end

      it { is_expected.to have_http_status(:ok) }

      context 'when only a single file champ are modified' do
        # A bug in ActiveRecord causes records changed through grand-parent <->  parent <-> child
        # relationships do not touch the grand-parent record on change.
        # This situation is hit when updating just the attachment of a champ (and not the
        # champ itself).
        #
        # This test ensures that, whatever workaround we wrote for this, it still works properly.
        #
        # See https://github.com/rails/rails/issues/26726
        let(:submit_payload) do
          {
            id: dossier.id,
            dossier: {
              champs_public_attributes: {
                piece_justificative_champ.public_id => {
                  piece_justificative_file: file,
                },
              },
            },
          }
        end

        it 'does not update the dossier timestamps' do
          subject
          dossier.reload
          expect(dossier.updated_at).not_to eq(now)
          expect(dossier.last_champ_updated_at).to be_nil
        end
      end
    end

    context 'when the update fails' do
      render_views

      context 'classic error' do
        before do
          allow_any_instance_of(Dossier).to receive(:save).and_return(false)
          allow_any_instance_of(Dossier).to receive(:errors).and_return(
            [message: 'nop', inner_error: double(base: first_champ_user_buffer)]
          )
          subject
        end

        it { expect(response).to render_template(:update) }

        it 'does not update the dossier timestamps' do
          dossier.reload
          expect(dossier.updated_at).not_to eq(now)
          expect(dossier.last_champ_updated_at).to be_nil
        end
      end

      context 'iban error' do
        let(:public_type_de_champs) { [{ type: :iban }] }
        let(:value) { 'abc' }

        before { subject }

        it 'does not update the dossier timestamps' do
          dossier.reload
          expect(dossier.updated_at).not_to eq(now)
          expect(dossier.last_champ_updated_at).to be_nil
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'when the user has an invitation but is not the owner' do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }
      let!(:invite) { create(:invite, dossier:, user:) }

      before { subject }

      it do
        dossier.reload
        expect(first_champ_user_buffer.value).to eq('beautiful value')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the champ is a phone number' do
      let(:public_type_de_champs) { [{ type: :phone }] }
      let(:now) { Time.zone.parse('01/01/2100') }

      let(:submit_payload) do
        {
          id: dossier.id,
          dossier: {
            champs_public_attributes: {
              first_champ.public_id => {
                value: value,
              },
            },
          },
        }
      end

      context 'with a valid value sent as string' do
        let(:value) { '0612345678' }
        it 'updates the value' do
          subject
          dossier.reload
          expect(first_champ_user_buffer.value).to eq('0612345678')
        end
      end

      context 'with a valid value sent as number' do
        let(:value) { '45187272'.to_i }
        it 'updates the value' do
          subject
          dossier.reload
          expect(first_champ_user_buffer.value).to eq('45187272')
        end
      end
    end

    context 'when the champ is an autocomplete with prefillable champs' do
      render_views
      let(:referentiel) { create(:api_referentiel, :exact_match, :with_exact_match_response) }
      let(:referentiel_stable_id) { 1 }
      let(:external_id) { "PG46YY6YWCX8" }
      let(:public_type_de_champs) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            stable_id: referentiel_stable_id,
          },
        ]
      end
      let (:submit_payload) do
        {
          id: dossier.id,
          dossier: {
            champs_public_attributes: {
              first_champ.public_id => {
                external_id:,
              },
            },
          },
        }
      end

      it 'includes enqueues job' do
        expect { subject }.to have_enqueued_job(ChampFetchExternalDataJob)
      end
    end

    context 'when the champ is an autocomplete with prefillable private champs' do
      render_views
      let(:datasource) { '$.data' }
      let(:referentiel) { create(:api_referentiel, :autocomplete, :with_autocomplete_response, datasource:) }
      let(:referentiel_stable_id) { 1 }
      let(:public_type_de_champs) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            stable_id: referentiel_stable_id,
            referentiel_mapping: {
              "$.data[0].finess" => { prefill: "1", prefill_stable_id: 100 },
            },
          },
        ]
      end
      let(:private_type_de_champs) do
        [
          {
            type: :text,
            stable_id: 100,
          },
        ]
      end
      let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }
      let(:suggestion_value) { 'osf' }
      let(:suggestion_data) { { finess: "123" } }
      let(:message_encryptor_service) { MessageEncryptorService.new }
      let(:submit_payload) do
        {
          id: dossier.id,
          dossier: {
            champs_public_attributes: {
              first_champ.public_id => {
                value: suggestion_value,
                data: message_encryptor_service.encrypt_and_sign(suggestion_data, purpose: :storage, expires_in: 1.hour),
              },
            },
          },
        }
      end

      it 'prefills the private annotation from the referentiel data' do
        subject

        dossier.reload
        annotation = dossier.root_champs_private.find { it.stable_id == 100 }
        expect(annotation.value).to be_nil

        dossier.with_update_stream(dossier.user) do
          referentiel = dossier.root_champs_public.find { it.stable_id == referentiel_stable_id }
          expect(referentiel.data.deep_symbolize_keys).to eq(data: [suggestion_data])
        end

        dossier.merge_user_buffer_stream!
        dossier.reload
        annotation = dossier.root_champs_private.find { it.stable_id == 100 }
        expect(annotation.value).to eq(suggestion_data[:finess])
        expect(annotation.stream).to eq(Dossier::MAIN_STREAM)
      end
    end

    context 'when the champ is quotient familial' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :quotient_familial }]) }

      context "when the champ has already been fetched, and user wants to refresh it" do
        let(:submit_payload) do
          {
            id: dossier.id,
            dossier: {
              champs_public_attributes: {
                first_champ.public_id => {
                  refresh_external_data: '1',
                },
              },
            },
          }
        end
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

        before do
          first_champ.update!(
            updated_at: 2.days.ago,
            external_state: 'fetched',
            data:,
            value_json:,
            value: 'true'
          )
        end

        it "first resets external data on user_buffer_stream" do
          allow(first_champ).to receive(:may_fetch_later?).and_return(false)
          expect(first_champ).not_to receive(:may_fetch_later!)
          subject
          dossier.reload
          expect(first_champ_user_buffer.data).to eq(nil)
          expect(first_champ_user_buffer.value_json).to eq(nil)
          expect(first_champ_user_buffer.value).to eq(nil)
          expect(first_champ_user_buffer.external_state).to eq('idle')
        end

        it "then calls fetch!" do
          allow_any_instance_of(Champs::QuotientFamilialChamp).to receive(:may_fetch_later?).and_return(true)

          expect(first_champ).not_to receive(:fetch_later!)
          expect_any_instance_of(Champs::QuotientFamilialChamp).to receive(:fetch_later!)
          subject
        end
      end
    end
  end

  describe '#champ' do
    let(:stable_id) { generate(:stable_id) }
    let(:public_type_de_champs) { [{ type: :text, stable_id: }] }
    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:, user:) }
    let(:champ) { dossier.champ_data.first }

    before do
      sign_in(user)
    end

    subject { get :champ, params: { id: dossier.id, stable_id:, row_id: nil }, format: :turbo_stream }

    context 'when the user owns the dossier' do
      it 'renders the turbo_stream update template' do
        subject
        expect(response).to render_template(:update)
        expect(assigns(:to_update)).to include(champ)
      end
    end

    context 'when the user does not own the dossier' do
      let(:other_user) { create(:user) }
      let(:dossier) { create(:dossier, user: other_user) }

      it 'redirects to the root path with an alert' do
        subject
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Vous n’avez pas accès à ce dossier")
      end
    end

    context 'live announcement of a RIB status (polling anti-spam)' do
      render_views
      let(:public_type_de_champs) { [{ type: :piece_justificative, nature: 'rib', stable_id: }] }
      let(:champ) { dossier.root_champs_public.first }
      let(:region_id) { "#{champ.focusable_input_id}-aria-live" }

      def announced_region(body)
        Nokogiri::HTML5.fragment(body).css(%(turbo-stream[action="update"][target="#{region_id}"]))
      end

      context 'while the analysis is still pending' do
        before { dossier.champ_data.first.update_column(:external_state, :waiting_for_job) }

        it 'does not re-announce the pending status on a poll' do
          subject
          expect(announced_region(response.body)).to be_empty
        end
      end

      context 'when the analysis has completed' do
        before { dossier.champ_data.first.update_columns(external_state: :fetched, value_json: { 'rib' => { 'iban' => 'FR7612345' } }) }

        it 'announces the result on the poll that observes completion' do
          subject
          expect(announced_region(response.body).text).to include('FR7612345')
        end
      end
    end

    context 'when champ is pollable' do
      let(:referentiel) { create(:api_referentiel, :exact_match) }
      let(:public_type_de_champs) { [{ type: :referentiel, referentiel:, stable_id: }] }

      context 'when the requested external_id had not been fetched' do
        before { dossier.champ_data.first.update_columns(external_id: 'kthxbye') }

        it 'does not validates errors' do
          subject
          expect(response).not_to include('Aucun résultat ne correspond à votre recherche.')
        end
      end

      context 'when the requested external_id had been fetched' do
        before { dossier.champ_data.find(&:referentiel?).update_columns(external_id: 'kthxbye', value: "OK", data: {}) }
        it 'validates errors' do
          subject
          expect(response).not_to include('Référence trouvée : OK')
        end

        context 'propagation du prefill (polling)' do
          render_views
          let(:referentiel) { create(:api_referentiel, :exact_match) }
          let(:referentiel_stable_id) { 1 }
          let(:public_type_de_champs) do
            [
              {
                type: :referentiel,
                referentiel: referentiel,
                stable_id: referentiel_stable_id,
                referentiel_mapping: {
                  "$.ok" => { prefill: "1", prefill_stable_id: 2 },
                  "$.repetition[0].nom" => { prefill: "1", prefill_stable_id: 3 },
                },
              },
              {
                type: :text,
                stable_id: 2, # mapped with "$.ok"
              },
              {
                type: :repetition,
                children: [
                  { type: :text, stable_id: 3 }, # mapped with "$.repetition{0}.nom"
                ],
              },
            ]
          end

          it 'inclut le champ principal et les champs pré-remplis dans @to_update' do
            dossier.champ_data.find(&:referentiel?).update_external_data!(data: { ok: 'valeur préremplie', repetition: [{ nom: 'Jeanne' }, { nom: "Bob" }, {}] })

            get :champ, params: { id: dossier.id, stable_id: referentiel_stable_id }, format: :turbo_stream

            expect(assigns(:to_update).size).to eq(3)
            expect(dossier.reload.champs.map(&:value)).to include('valeur préremplie')
            expect(response.body).to include('Donnée remplie automatiquement.')
            expect(response.body).to include('Jeanne')
            expect(response.body).to include('Bob')
          end
        end
      end

      context 'when the requested external_id is in error' do
        before { dossier.champ_data.first.update_columns(external_id: 'kthxbye', value: "OK", fetch_external_data_exceptions: [ExternalDataException.new(error: "thxbye", code: 429)]) }
        it 'validates errors' do
          subject
          expect(response).not_to include('Trop de demandes. Nous réessayons pour vous.')
        end
      end

      context 'when a conditional champ exists alongside the polled champ' do
        include Logic

        let(:async_stable_id) { 10 }
        let(:checkbox_stable_id) { 20 }
        let(:explication_stable_id) { 30 }
        let(:condition) { ds_eq(champ_value(checkbox_stable_id), constant(true)) }
        let(:public_type_de_champs) do
          [
            { type: :referentiel, referentiel:, stable_id: async_stable_id },
            { type: :checkbox, stable_id: checkbox_stable_id },
            { type: :explication, stable_id: explication_stable_id, condition: },
          ]
        end
        let(:stable_id) { async_stable_id }

        before do
          dossier.champ_data.find(&:referentiel?).update_columns(external_id: 'kthxbye', value: 'OK', data: {})
          dossier.champ_data.find { _1.stable_id == checkbox_stable_id }.update_columns(value: 'true')
        end

        it 'recomputes visibility of conditional champs after polling' do
          subject

          explication_champ = assigns(:dossier).flat_champs_public
            .find { _1.type_de_champ.stable_id == explication_stable_id }
          expect(assigns(:to_show)).to include("##{explication_champ.input_group_id}")
        end
      end
    end
  end
end
