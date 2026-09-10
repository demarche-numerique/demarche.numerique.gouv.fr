# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users.usager }

  describe '#brouillon' do
    before { sign_in(user) }
    let!(:dossier) { create(:dossier, user: user, autorisation_donnees: true, procedure: procedures.entreprise) }

    subject { get :brouillon, params: { id: dossier.id } }

    context 'when autorisation_donnees is checked' do
      it { is_expected.to render_template(:brouillon) }
    end

    context 'when autorisation_donnees is not checked' do
      before { dossier.update_columns(autorisation_donnees: false) }

      context 'when the dossier is for personne morale' do
        it { is_expected.to redirect_to(siret_dossier_path(dossier)) }
      end

      context 'when the dossier is for an personne physique' do
        before { dossier.procedure.update(for_individual: true) }

        it { is_expected.to redirect_to(identite_dossier_path(dossier)) }
      end
    end

    context 'when the dossier is en_construction' do
      let!(:dossier) { dossiers.en_construction }
      it { is_expected.to redirect_to(modifier_dossier_path(dossier)) }
    end
  end

  describe '#edit' do
    before { sign_in(user) }
    let!(:dossier) { create(:dossier, user: user, procedure: procedures.entreprise) }

    it 'returns the edit page' do
      get :brouillon, params: { id: dossier.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe '#submit_brouillon' do
    before { sign_in(user) }
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) { [{ type: :text, mandatory: false }] }
    let!(:dossier) { create(:dossier, user:, procedure:) }
    let(:first_champ) { dossier.root_champs_public.first }
    let(:value) { 'beautiful value' }
    let(:now) { Time.zone.parse('01/01/2100') }
    let(:payload) { { id: dossier.id } }

    subject do
      travel_to now
      post :submit_brouillon, params: payload
    end

    context 'when the dossier cannot be updated by the user' do
      let!(:dossier) { create(:dossier, :en_instruction, user: user) }

      it 'redirects to the dossiers list' do
        subject

        expect(response).to redirect_to(dossier_path(dossier))
        expect(flash.alert).to eq('Votre dossier ne peut plus être modifié')
      end
    end

    it 'sends an email only on the first #update_brouillon' do
      delivery = double
      expect(delivery).to receive(:deliver_later).with(no_args)

      expect(NotificationMailer).to receive(:send_en_construction_notification)
        .and_return(delivery)

      subject

      expect(NotificationMailer).not_to receive(:send_en_construction_notification)

      subject
    end

    context 'when the update fails' do
      render_views
      let(:error_message) { 'nop' }
      before do
        allow_any_instance_of(Dossier).to receive(:validate).and_return(false)
        allow_any_instance_of(Dossier).to receive(:errors).and_return(
          [double(base: first_champ, attribute: :value, message: 'nop')]
        )
        subject
      end

      it do
        expect(response).to render_template(:brouillon)
        expect(response.body).to have_link(first_champ.libelle, href: "##{first_champ.focusable_input_id}")
        expect(response.body).to have_content(error_message)
      end

      it 'does not send an email' do
        expect(NotificationMailer).not_to receive(:send_en_construction_notification)

        subject
      end
    end

    context 'when a mandatory champ is missing' do
      render_views

      let(:value) { nil }
      let(:public_type_de_champs) { [{ type: :text, mandatory: true, libelle: 'l' }] }
      before { subject }

      it do
        expect(response).to render_template(:brouillon)
        expect(response.body).to have_link(first_champ.libelle, href: "##{first_champ.focusable_input_id}")
        expect(response.body).to have_content("doit être rempli")
      end
    end

    context 'when dossier has no champ' do
      let(:submit_payload) { { id: dossier.id } }

      it 'does not raise any errors' do
        subject

        expect(response).to redirect_to(merci_dossier_path(dossier))
      end
    end

    context 'when the user has an invitation but is not the owner' do
      let(:dossier) { create(:dossier) }
      let!(:invite) { create(:invite, dossier: dossier, user: user) }

      context 'and the invite tries to submit the dossier' do
        before { subject }

        it do
          expect(response).to redirect_to(root_path)
          expect(flash.alert).to include("Vous n’avez pas accès à ce dossier")
        end
      end
    end

    context 'when procedure has sva enabled' do
      let(:procedure) { create(:procedure, :sva) }
      let!(:dossier) { create(:dossier, :brouillon, procedure:, user:) }

      it 'passe automatiquement en instruction' do
        delivery = double.tap { expect(_1).to receive(:deliver_later).with(no_args).twice }
        expect(NotificationMailer).to receive(:send_en_construction_notification).and_return(delivery)
        expect(NotificationMailer).to receive(:send_en_instruction_notification).and_return(delivery)

        subject
        dossier.reload

        expect(dossier).to be_en_instruction
        expect(dossier.pending_correction?).to be_falsey
        expect(dossier.en_instruction_at).to within(5.seconds).of(Time.current)
        expect(dossier.traitements.last.browser_name).to eq('Unknown Browser')
      end
    end

    context 'when user logged via france connect' do
      before { user.update!(loged_in_with_france_connect: 'particulier') }

      it 'sets submitted_with_france_connect to true' do
        subject
        dossier.reload
        expect(dossier.submitted_with_france_connect).to be true
      end
    end

    context 'when user not logged via france connect' do
      before { user.update!(loged_in_with_france_connect: nil) }

      it 'sets submitted_with_france_connect to false' do
        subject
        dossier.reload
        expect(dossier.submitted_with_france_connect).to be false
      end
    end

    context 'when user logged via pro connect' do
      before do
        cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { value: { user_id: user.id }.to_json }
      end

      it 'sets submitted_with_pro_connect to true' do
        subject
        dossier.reload
        expect(dossier.submitted_with_pro_connect).to be true
      end
    end

    context 'when user not logged via pro connect' do
      it 'sets submitted_with_pro_connect to false' do
        subject
        dossier.reload
        expect(dossier.submitted_with_pro_connect).to be false
      end
    end
  end

  describe '#update brouillon' do
    before { sign_in(user) }

    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) { [{}, { type: :piece_justificative, mandatory: false }] }
    let(:dossier) { create(:dossier, user:, procedure:, brouillon_close_to_expiration_notice_sent_at: 10.days.ago) }
    let(:first_champ) { dossier.root_champs_public.first }
    let(:piece_justificative_champ) { dossier.root_champs_public.last }
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

    # RAILS-JYN: the admin published a revision removing this champ while the usager still
    # had the form open, and the dossier was rebased onto it. The autosave keeps coming.
    context 'when a newly published revision removed the champ' do
      let!(:removed_stable_id) { first_champ.stable_id }
      let(:champs_public_attributes) { { removed_stable_id.to_s => { value: 'still typing' } } }

      before do
        procedure.draft_revision.remove_type_de_champ(removed_stable_id)
        procedure.publish_revision!(procedure.administrateurs.first)
        dossier.reload.rebase!
      end

      it 'removes the orphaned input and leaves the rest of the page alone' do
        subject

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="remove"')
        expect(response.body).to include("#champ-#{removed_stable_id}")
      end
    end

    context 'when the champ is a drop_down_list with referentiel' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :drop_down_list }]) }

      let(:referentiel) { create(:csv_referentiel, :with_items) }

      let(:value) { referentiel.items.first.id }

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
        before { procedure.active_revision.public_root_type_de_champs.first.update!(drop_down_mode: 'advanced', referentiel:) }

        it 'updates the value' do
          subject
          expect(first_champ.reload.value).to eq(referentiel.items.first.id.to_s)
          expect(first_champ.reload.referentiel.fetch('data')).to eq(referentiel.items.first.data.merge('headers' => referentiel.headers))
        end
      end
    end

    context 'when the champ is a multiple_drop_down_list with referentiel' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :multiple_drop_down_list }]) }

      let(:referentiel) { create(:csv_referentiel, :with_items) }

      let(:value) { [referentiel.items.first.id, referentiel.items.second.id].to_json }
      let(:keys) { JSON.parse(value).map(&:to_s) }

      let(:submit_payload) do
        {
          id: dossier.id,
          dossier: {
            champs_public_attributes: {
              first_champ.public_id => {
                value:,
              },
            },
          },
        }
      end

      context 'with a valid value sent as string' do
        before { procedure.active_revision.public_root_type_de_champs.first.update!(drop_down_mode: 'advanced', referentiel:) }

        it 'updates the value' do
          subject
          expect(first_champ.reload.value).to eq(value)
          expect(first_champ.reload.referentiels.keys).to eq(keys)
          expect(first_champ.reload.referentiels).to eq({ keys.first => { 'data' => referentiel.items.first.data.merge('headers' => referentiel.headers) }, keys.second => { 'data' => referentiel.items.second.data.merge('headers' => referentiel.headers) } })
        end
      end
    end

    context 'when the champ is an address' do
      let(:public_type_de_champs) { [{ type: :address }] }
      let(:address_champ) { dossier.champ_data.first }
      let(:initial_value_json) do
        {
          'label' => '33 Rue Rébeval 75019 Paris',
          'city_code' => '75119',
          'city_name' => 'Paris',
          'postal_code' => '75019',
          'street_address' => '33 Rue Rébeval',
          'department_code' => '75',
          'department_name' => 'Paris',
        }
      end

      before { address_champ.update!(value: '33 Rue Rébeval 75019 Paris', value_json: initial_value_json) }

      context 'when not_in_ban is not set (regular BAN address)' do
        let(:champs_public_attributes) do
          { address_champ.public_id => { street_address: 'donnée injectée' } }
        end

        it 'does not permit the out-of-BAN address fields and keeps the original data intact' do
          subject
          expect(address_champ.reload.value_json['street_address']).to eq('33 Rue Rébeval')
        end
      end

      context 'when not_in_ban is true' do
        let(:champs_public_attributes) do
          {
            address_champ.public_id => {
              not_in_ban: 'true',
              street_address: '12 rue du Test',
              city_name: 'Lyon',
              postal_code: '69001',
            },
          }
        end

        it 'permits the out-of-BAN address fields' do
          subject
          address_champ.reload
          expect(address_champ.not_ban?).to be_truthy
          expect(address_champ.value_json['street_address']).to eq('12 rue du Test')
          expect(address_champ.value_json['city_name']).to eq('Lyon')
          expect(address_champ.value_json['postal_code']).to eq('69001')
        end
      end
    end

    context 'when the dossier cannot be updated by the user' do
      let(:dossier) { create(:dossier, :en_instruction, user:, procedure:) }

      it 'redirects to the dossiers list' do
        subject

        expect(response).to redirect_to(dossier_path(dossier))
        expect(flash.alert).to eq('Votre dossier ne peut plus être modifié')
      end
    end

    context 'when dossier can be updated by the owner' do
      it 'updates the champs' do
        subject
        expect(response).to have_http_status(:ok)
        expect(dossier.reload.updated_at.year).to eq(2100)
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:brouillon))
        expect(dossier.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil
        expect(first_champ.reload.value).to eq('beautiful value')
      end

      context 'updates the pj' do
        let(:champs_public_attributes) do
          {
            piece_justificative_champ.public_id => { piece_justificative_file: file },
          }
        end

        it do
          subject
          expect(piece_justificative_champ.reload.piece_justificative_file).to be_attached
        end
      end

      it 'updates the dossier timestamps' do
        subject
        dossier.reload
        expect(dossier.updated_at).to eq(now)
        expect(dossier.last_champ_updated_at).to eq(now)
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
        let(:champs_public_attributes) do
          {
            piece_justificative_champ.public_id => { piece_justificative_file: file },
          }
        end

        it 'updates the dossier timestamps' do
          subject
          dossier.reload
          expect(dossier.updated_at).to eq(now)
          expect(dossier.last_champ_updated_at).to eq(now)
        end
      end

      context 'when the champ is a siret champ' do
        let(:public_type_de_champs) { [{ type: :siret }] }
        let(:champs_public_attributes) do
          {
            first_champ.public_id => { external_id: },
          }
        end

        before do
          first_champ.update_columns(external_state: 'fetched', etablissement_id: create(:etablissement).id)
        end

        context 'when the SIRET is invalid' do
          let(:external_id) { 'nomatterthereason' }
          it 'resets its etablissement' do
            expect { subject }.to change { first_champ.reload.etablissement }.from(an_instance_of(Etablissement)).to(nil)
          end
        end

        context 'when the SIRET is empty' do
          let(:external_id) { '' }

          it { expect { subject }.not_to have_enqueued_job(ChampFetchExternalDataJob) }
        end

        context "when the SIRET is invalid because of it's length" do
          let(:external_id) { '1234' }

          it { expect { subject }.not_to have_enqueued_job(ChampFetchExternalDataJob) }
        end

        context "when the SIRET is invalid because of it's checksum" do
          let(:external_id) { '82812345600023' }

          it { expect { subject }.not_to have_enqueued_job(ChampFetchExternalDataJob) }
        end
      end
      context 'when the champ is an external champ in fetched state' do
        let(:public_type_de_champs) { [{ type: :rnf }] }
        let(:champs_public_attributes) do
          {
            first_champ.public_id => { external_id: '075-FDD-00003-01' },
          }
        end

        before do
          expect_any_instance_of(ChampData).to receive(:fetch_external_data_later)
          first_champ.update_columns(external_state: 'fetched', value_json: 'a value')
        end

        it 'resets its data and launches the fetching process' do
          subject
          first_champ.reload
          expect(first_champ.external_state).to eq('waiting_for_job')
          expect(first_champ.value_json).to be_nil
        end
      end
    end

    context 'when the user has an invitation but is not the owner' do
      let(:dossier) { create(:dossier, procedure: procedure) }
      let!(:invite) { create(:invite, dossier: dossier, user: user) }

      before { subject }

      it do
        expect(first_champ.reload.value).to eq('beautiful value')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'decimal number champ separator' do
      let (:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :decimal_number }]) }
      let (:submit_payload) do
        {
          id: dossier.id,
          dossier: {
            champs_public_attributes: { first_champ.public_id => { value: } },
          },
        }
      end

      context 'when spearator is dot' do
        let(:value) { '3.14' }

        it "saves the value" do
          subject
          expect(first_champ.reload.value).to eq('3.14')
        end
      end

      context 'when spearator is comma' do
        let(:value) { '3,14' }

        it "saves the value" do
          subject
          expect(first_champ.reload.value).to eq('3.14')
        end
      end
    end

    context 'having ineligibilite_rules setup' do
      include Logic
      render_views

      let(:public_type_de_champs) { [{ type: :text }, { type: :integer_number }] }
      let(:text_champ) { dossier.root_champs_public.first }
      let(:number_champ) { dossier.root_champs_public.last }
      let(:validate) { "true" }
      let(:submit_payload) do
        {
          id: dossier.id,
          validate:,
          dossier: {
            champs_public_attributes: {
              number_champ.public_id => { value: },
            },
          },
        }
      end
      let(:must_be_greater_than) { 10 }

      before do
        procedure.published_revision.update(
          ineligibilite_enabled: true,
          ineligibilite_message: 'lol',
          ineligibilite_rules: greater_than(champ_value(number_champ.stable_id), constant(must_be_greater_than))
        )
        procedure.published_revision.save!
      end
      render_views

      context 'when it becomes invalid' do
        let(:value) { must_be_greater_than + 1 }

        it 'raises popup' do
          subject
          dossier.reload
          expect(dossier.can_passer_en_construction?).to be_falsey
          expect(response.body).to match(/aria-controls='modal-eligibilite-rules-dialog'[^>]*data-fr-opened='true'/)
        end
      end

      context 'when it says valid' do
        let(:value) { must_be_greater_than - 1 }
        it 'does nothing' do
          subject
          dossier.reload
          expect(dossier.can_passer_en_construction?).to be_truthy
          expect(response.body).to match(/aria-controls='modal-eligibilite-rules-dialog'[^>]*data-fr-opened='false'/)
        end
      end

      context 'when not validating' do
        let(:validate) { nil }
        let(:value) { must_be_greater_than + 1 }

        it 'does not render invalid ineligible modal' do
          subject
          dossier.reload
          expect(dossier.can_passer_en_construction?).to be_falsey
          expect(response.body).not_to include("aria-controls='modal-eligibilite-rules-dialog'")
        end
      end
    end

    context 'when the champ is an autocomplete with prefillable champs' do
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
              "$.data[0].finess" => { prefill: "1", prefill_stable_id: 2 },
              "$.data[0].ej_rs" => { prefill: "1", prefill_stable_id: 3 },
            },
          },
          {
            type: :text,
            stable_id: 2,
          },
          {
            type: :text,
            stable_id: 3,
          },
        ]
      end
      let(:suggestion_value) { 'osf' }
      let(:suggestion_data) { { finess: "123", ej_rs: "456" } }
      let(:message_encryptor_service) { MessageEncryptorService.new }
      let (:submit_payload) do
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

      it 'includes the referentiel champ plus its prefillable champs within @to_update' do
        subject

        expect(assigns(:to_update).size).to eq(3)

        dossier.reload

        # check data persistence
        champs = dossier.champs
        champ_referentiel = champs.find(&:referentiel?)
        expect(champ_referentiel.value).to eq(suggestion_value)
        expect(champ_referentiel.data).to eq(champ_referentiel.send(:rewrap_selected_object_in_datasource, suggestion_data.with_indifferent_access))

        expect(champs.find { it.stable_id == 2 }.reload.value).to eq(suggestion_data[:finess])
        expect(champs.find { it.stable_id == 3 }.reload.value).to eq(suggestion_data[:ej_rs])

        # check rendering
        expect(response.body).to include(suggestion_value)
        expect(response.body).to include(suggestion_data[:finess])
        expect(response.body).to include(suggestion_data[:ej_rs])
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

        it "first resets external data" do
          allow(first_champ).to receive(:may_fetch_later?).and_return(false)

          expect {
            subject
            first_champ.reload
          }.to change { first_champ.data }.to(nil)
            .and change { first_champ.value_json }.to(nil)
            .and change { first_champ.value }.to(nil)
        end

        it "then calls fetch!" do
          allow_any_instance_of(Champs::QuotientFamilialChamp).to receive(:may_fetch_later?).and_return(true)

          expect_any_instance_of(Champs::QuotientFamilialChamp).to receive(:fetch_later!)
          subject
        end
      end
    end
  end
end
