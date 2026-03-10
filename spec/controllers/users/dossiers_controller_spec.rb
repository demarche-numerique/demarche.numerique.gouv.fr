# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users(:default_user) }

  describe 'before_actions' do
    it 'are present' do
      before_actions = Users::DossiersController
        ._process_action_callbacks
        .filter { |process_action_callbacks| process_action_callbacks.kind == :before }
        .map(&:filter)

      expect(before_actions).to include(:ensure_ownership!, :ensure_ownership_or_invitation!)
    end
  end

  shared_examples_for 'does not redirect nor flash' do
    before { @controller.send(ensure_authorized) }

    it do
      expect(@controller).not_to have_received(:redirect_to)
      expect(flash.alert).to eq(nil)
    end
  end

  shared_examples_for 'redirects and flashes' do
    before { @controller.send(ensure_authorized) }

    it do
      expect(@controller).to have_received(:redirect_to).with(root_path)
      expect(flash.alert).to include("Vous n’avez pas accès à ce dossier")
    end
  end

  describe '#ensure_ownership!' do
    let(:user) { create(:user) }
    let(:asked_dossier) { create(:dossier) }
    let(:ensure_authorized) { :ensure_ownership! }

    before do
      @controller.params = @controller.params.merge(dossier_id: asked_dossier.id)
      allow(@controller).to receive(:redirect_to)
    end

    context 'when a user asks for their own dossier' do
      before do
        expect(@controller).to receive(:current_user).and_return(user)
      end

      let(:asked_dossier) { create(:dossier, user: user) }

      it_behaves_like 'does not redirect nor flash'
    end

    context 'when a user asks for another dossier' do
      before do
        expect(@controller).to receive(:current_user).twice.and_return(user)
      end

      it_behaves_like 'redirects and flashes'
    end

    context 'when an invite asks for a dossier where they were invited' do
      before do
        expect(@controller).to receive(:current_user).twice.and_return(user)
        create(:invite, dossier: asked_dossier, user: user)
      end

      it_behaves_like 'redirects and flashes'
    end

    context 'when an invite asks for another dossier' do
      before do
        expect(@controller).to receive(:current_user).twice.and_return(user)
        create(:invite, dossier: create(:dossier), user: user)
      end

      it_behaves_like 'redirects and flashes'
    end
  end

  describe '#ensure_ownership_or_invitation!' do
    let(:asked_dossier) { create(:dossier) }
    let(:ensure_authorized) { :ensure_ownership_or_invitation! }

    before do
      @controller.params = @controller.params.merge(dossier_id: asked_dossier.id)
      allow(@controller).to receive(:redirect_to)
    end

    context 'when a user asks for their own dossier' do
      before do
        expect(@controller).to receive(:current_user).and_return(user)
      end

      let(:asked_dossier) { create(:dossier, user: user) }

      it_behaves_like 'does not redirect nor flash'
    end

    context 'when a user asks for another dossier' do
      before do
        expect(@controller).to receive(:current_user).twice.and_return(user)
      end

      it_behaves_like 'redirects and flashes'
    end

    context 'when an invite asks for a dossier where they were invited' do
      before do
        expect(@controller).to receive(:current_user).and_return(user)
        create(:invite, dossier: asked_dossier, user: user)
      end

      it_behaves_like 'does not redirect nor flash'
    end

    context 'when an invite asks for another dossier' do
      before do
        expect(@controller).to receive(:current_user).twice.and_return(user)
        create(:invite, dossier: create(:dossier), user: user)
      end

      it_behaves_like 'redirects and flashes'
    end
  end

  describe 'attestation' do
    before { sign_in(user) }

    context 'when a dossier has an attestation' do
      let(:dossier) { create(:dossier, :accepte, attestation: create(:attestation, :with_pdf), user: user) }

      it 'redirects to attestation pdf' do
        get :attestation, params: { id: dossier.id }
        expect(response.location).to match '/rails/active_storage/disk/'
      end

      context 'when the dossier is expired by automatic' do
        before do
          dossier.hide_and_keep_track!(:automatic, :expired)
        end

        it 'redirects to attestation pdf' do
          get :attestation, params: { id: dossier.id }
          expect(response.location).to match '/rails/active_storage/disk/'
        end
      end
    end
  end

  describe 'identite with france connect' do
    let(:procedure) { create(:procedure, :for_individual, for_tiers_enabled: true) }
    let(:dossier) { create(:dossier, user:, procedure:) }

    before { sign_in(user) }

    describe 'turbo_stream format' do
      let(:user) { create(:user, france_connect_informations: [build(:france_connect_information)]) }

      subject { patch :identite, params: { id: dossier.id, dossier: { for_tiers: for_tiers_value } }, format: :turbo_stream }

      context 'when switching to for_tiers' do
        let(:for_tiers_value) { 'true' }

        it 'prefills mandataire and resets individual' do
          subject
          expect(assigns(:dossier).for_tiers).to be true
          expect(assigns(:dossier).mandataire_first_name).to eq('Angela Claire Louise')
          expect(assigns(:dossier).mandataire_last_name).to eq('DUBOIS')
          expect(assigns(:dossier).individual.nom).to be_nil
        end
      end

      context 'when switching back to for_self' do
        let(:dossier) { create(:dossier, :for_tiers_without_notification, user:, procedure:) }
        let(:for_tiers_value) { 'false' }

        before { dossier.individual.update_columns(nom: nil, prenom: nil, gender: nil) }

        it 'prefills individual from FranceConnect' do
          subject
          expect(assigns(:dossier).for_tiers).to be false
          expect(assigns(:dossier).individual.nom).to eq('DUBOIS')
          expect(assigns(:dossier).individual.prenom).to eq('Angela Claire Louise')
        end
      end
    end
  end

  describe 'update_identite' do
    let(:procedure) { create(:procedure, :for_individual) }
    let(:dossier) { create(:dossier, user: user, procedure: procedure) }

    subject { post :update_identite, params: { id: dossier.id, dossier: dossier_params } }

    before do
      sign_in(user)
    end

    context 'with correct individual and dossier params' do
      let(:dossier_params) { { individual_attributes: { gender: 'M', nom: 'Mouse', prenom: 'Mickey' } } }
      let(:now) { Time.zone.parse('01/01/2100') }
      before do
        travel_to(now) do
          subject
        end
      end

      it do
        expect(response).to redirect_to(brouillon_dossier_path(dossier))
        expect(dossier.reload.identity_updated_at).to eq(now)
      end
    end

    context "when at least one instructeur wants dossier_modifie notification" do
      let(:dossier_params) { { individual_attributes: { gender: 'M', nom: 'Mouse', prenom: 'Mickey' } } }
      let(:instructeur) { create(:instructeur) }
      let!(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur], procedure:) }
      let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, display_dossier_modifie_notifications: 'all') }

      context "when the dossier is en_construction" do
        let(:dossier) { create(:dossier, :en_construction, user:, groupe_instructeur:, procedure:) }

        it "creates dossier_modifie notification" do
          expect { subject }.to change(DossierNotification, :count).by(1)

          notification = DossierNotification.last
          expect(notification.dossier_id).to eq(dossier.id)
          expect(notification.instructeur_id).to eq(instructeur.id)
          expect(notification.notification_type).to eq("dossier_modifie")
        end
      end

      context "when the dossier is in brouillon" do
        let(:dossier) { create(:dossier, :brouillon, user:, groupe_instructeur:, procedure:) }

        it "does not create dossier_modifie notification" do
          expect { subject }.not_to change(DossierNotification, :count)
        end
      end
    end

    context 'when the identite cannot be updated by the user' do
      let(:dossier) { create(:dossier, :with_individual, :en_instruction, user: user, procedure: procedure) }
      let(:dossier_params) { { individual_attributes: { gender: 'M', nom: 'Mouse', prenom: 'Mickey' } } }
      before { subject }

      it 'redirects to the dossiers list' do
        expect(response).to redirect_to(dossier_path(dossier))
        expect(flash.alert).to eq('Votre dossier ne peut plus être modifié')
      end
    end

    context 'with incorrect individual and dossier params' do
      let(:dossier_params) { { individual_attributes: { nom: '', prenom: '' } } }
      before { subject }

      it do
        expect(response).not_to have_http_status(:redirect)
        expect(flash[:alert]).to include("Le champ « Nom » doit être rempli", "Le champ « Prénom » doit être rempli")
      end
    end

    context 'when a dossier is in brouillon, for_tiers and we want to update the individual' do
      let(:dossier) { create(:dossier, :for_tiers_without_notification, state: "brouillon", user: user, procedure: procedure) }
      let(:dossier_params) { { individual_attributes: { gender: 'M', nom: 'Mouse', prenom: 'Mickey', email: 'mickey@gmail.com', notification_method: 'email' } } }

      it 'updates the individual with valid notification_method' do
        expect { subject }.to have_enqueued_mail(UserMailer, :invite_tiers)
          .and change(User, :count).by(1)

        dossier.reload
        individual = dossier.individual.reload
        expect(individual.errors.full_messages).to be_empty
        expect(individual.notification_method).to eq('email')
        expect(individual.email).to eq('mickey@gmail.com')
        expect(individual.email_verified_at).to eq nil
        expect(response).to redirect_to(brouillon_dossier_path(dossier))
      end

      context 'when we want to change the mandataire' do
        let(:dossier_params) { { mandataire_first_name: "Jean", mandataire_last_name: "Dupont" } }

        it 'updates the dossier mandataire first and last name' do
          expect { subject }.not_to have_enqueued_mail(UserMailer, :invite_tiers)

          dossier.reload
          individual = dossier.individual.reload
          expect(dossier.errors.full_messages).to be_empty
          expect(dossier.mandataire_first_name).to eq('Jean')
          expect(dossier.mandataire_last_name).to eq('Dupont')
          expect(dossier.mandataire_full_name).to eq('Jean Dupont')
        end
      end
    end
  end

  describe '#siret' do
    before { sign_in(user) }
    let!(:dossier) { create(:dossier, user: user) }

    subject { get :siret, params: { id: dossier.id } }

    it { is_expected.to render_template(:siret) }
  end

  describe '#update_siret' do
    let(:dossier) { create(:dossier, user: user) }
    let(:siret) { params_siret.delete(' ') }
    let(:siren) { siret[0..8] }
    let(:api_etablissement_status) { 200 }
    let(:api_etablissement_body) { Rails.root.join('spec/fixtures/files/api_entreprise/etablissements.json').read }
    let(:token_expired) { false }
    let(:api_insee_status_response) { nil }

    before do
      sign_in(user)
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(status: api_etablissement_status, body: api_etablissement_body)
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/unites_legales\/#{siren}/)
        .to_return(body: Rails.root.join('spec/fixtures/files/api_entreprise/ping.json').read, status: 200)
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles)
        .and_return(["attestations_fiscales", "attestations_sociales", "bilans_entreprise_bdf"])
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(token_expired)

      if api_insee_status_response
        stub_request(:get, "https://entreprise.api.gouv.fr/ping/insee/sirene")
          .to_return(body: api_insee_status_response)
      end
      travel_to(2.minutes.ago)
    end

    subject! { post :update_siret, params: { id: dossier.id, user: { siret: params_siret } } }

    shared_examples 'SIRET informations are successfully saved' do
      it do
        dossier.reload
        user.reload

        expect(dossier.etablissement).to be_present
        expect(dossier.autorisation_donnees).to be(true)
        expect(user.siret).to eq(siret)
        expect(dossier.last_champ_updated_at).to be_between(2.seconds.ago, Time.current.to_i)
        expect(response).to redirect_to(etablissement_dossier_path)
      end
    end

    shared_examples 'the request fails with an error' do |error|
      it 'doesn’t save an etablissement' do
        expect(dossier.reload.etablissement).to be_nil
      end

      it 'displays the SIRET that was sent by the user in the form' do
        expect(controller.current_user.siret).to eq(siret)
      end

      it 'renders an error' do
        expect(flash.alert).to eq(error)
        expect(response).to render_template(:siret)
      end
    end

    context 'with an invalid SIRET' do
      let(:params_siret) { '000 000' }

      it_behaves_like 'the request fails with an error', ['Le champ « Siret » doit comporter exactement 14 chiffres. Exemple : 500 001 234 56789']
    end

    context 'with a valid SIRET' do
      let(:params_siret) { '418 166 096 00051' }

      context 'When API-Entreprise is ponctually down' do
        let(:api_etablissement_status) { 502 }
        let(:api_insee_status_response) { Rails.root.join('spec/fixtures/files/api_entreprise/ping.json').read }

        it_behaves_like 'the request fails with an error', I18n.t('errors.messages.siret.network_error')
      end

      context 'When API-Entreprise is globally down' do
        let(:api_etablissement_status) { 502 }
        let(:api_insee_status_response) { Rails.root.join('spec/fixtures/files/api_entreprise/ping.json').read.gsub('ok', 'HASISSUES') }

        it "create an etablissement only with SIRET as degraded mode" do
          dossier.reload
          expect(dossier.etablissement.siret).to eq(siret)
          expect(dossier.etablissement).to be_as_degraded_mode
        end
      end

      context 'when API-Entreprise doesn’t know this SIRET' do
        let(:api_etablissement_status) { 404 }

        it_behaves_like 'the request fails with an error', I18n.t('errors.messages.siret.not_found')
      end

      context 'when default token has expired' do
        let(:api_etablissement_status) { 200 }
        let(:api_insee_status_response) { Rails.root.join('spec/fixtures/files/api_entreprise/ping.json').read }
        let(:token_expired) { true }

        it_behaves_like 'the request fails with an error', I18n.t('errors.messages.siret.network_error')
      end

      context 'when all API informations available' do
        it_behaves_like 'SIRET informations are successfully saved'

        it 'saves the associated informations on the etablissement' do
          dossier.reload
          expect(dossier.etablissement.entreprise).to be_present
        end
      end
    end
  end

  describe '#etablissement' do
    let(:dossier) { create(:dossier, :with_entreprise, user: user) }

    before { sign_in(user) }

    subject { get :etablissement, params: { id: dossier.id } }

    it { is_expected.to render_template(:etablissement) }

    context 'when the dossier has no etablissement yet' do
      let(:dossier) { create(:dossier, user: user) }
      it { is_expected.to redirect_to siret_dossier_path(dossier) }
    end
  end

  describe '#brouillon' do
    before { sign_in(user) }
    let!(:dossier) { create(:dossier, user: user, autorisation_donnees: true) }

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
      let!(:dossier) { create(:dossier, :en_construction, user: user, autorisation_donnees: true) }
      it { is_expected.to redirect_to(modifier_dossier_path(dossier)) }
    end
  end

  describe '#edit' do
    before { sign_in(user) }
    let!(:dossier) { create(:dossier, user: user) }

    it 'returns the edit page' do
      get :brouillon, params: { id: dossier.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe '#submit_brouillon' do
    before { sign_in(user) }
    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :text, mandatory: false }] }
    let!(:dossier) { create(:dossier, user:, procedure:) }
    let(:first_champ) { dossier.project_champs_public.first }
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
      let(:types_de_champ_public) { [{ type: :text, mandatory: true, libelle: 'l' }] }
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
  end

  describe '#submit_en_construction (stream)' do
    let(:owner) { create(:user) }
    let(:procedure_traits) { [] }
    let(:dossier_traits) { [] }
    let(:procedure) { create(:procedure, :for_individual, :published, *procedure_traits, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :text, mandatory: false }] }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, *dossier_traits, procedure:, user: owner).tap { _1.with_update_stream(_1.user) } }
    let(:now) { Time.zone.parse('01/01/2100') }
    let(:params) { { id: dossier.id } }
    let(:champs) { dossier.project_champs_public }
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
        let(:types_de_champ_public) { [{}, { type: :text, mandatory: true, libelle: 'l' }] }
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
        let(:types_de_champ_public) { [{}, { type: :repetition, libelle: 'repetition', children: [{ type: :text, libelle: 'child' }] }] }
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
  end

  describe '#update brouillon' do
    before { sign_in(user) }

    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let(:types_de_champ_public) { [{}, { type: :piece_justificative, mandatory: false }] }
    let(:dossier) { create(:dossier, user:, procedure:, brouillon_close_to_expiration_notice_sent_at: 10.days.ago) }
    let(:first_champ) { dossier.project_champs_public.first }
    let(:piece_justificative_champ) { dossier.project_champs_public.last }
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

    context 'when the champ is a drop_down_list with referentiel' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :drop_down_list }]) }

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
        before { procedure.active_revision.types_de_champ_public.first.update!(drop_down_mode: 'advanced', referentiel:) }

        it 'updates the value' do
          subject
          expect(first_champ.reload.value).to eq(referentiel.items.first.id.to_s)
          expect(first_champ.reload.referentiel.fetch('data')).to eq(referentiel.items.first.data.merge('headers' => referentiel.headers))
        end
      end
    end

    context 'when the champ is a multiple_drop_down_list with referentiel' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :multiple_drop_down_list }]) }

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
        before { procedure.active_revision.types_de_champ_public.first.update!(drop_down_mode: 'advanced', referentiel:) }

        it 'updates the value' do
          subject
          expect(first_champ.reload.value).to eq(value)
          expect(first_champ.reload.referentiels.keys).to eq(keys)
          expect(first_champ.reload.referentiels).to eq({ keys.first => { 'data' => referentiel.items.first.data.merge('headers' => referentiel.headers) }, keys.second => { 'data' => referentiel.items.second.data.merge('headers' => referentiel.headers) } })
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
        let(:types_de_champ_public) { [{ type: :siret }] }
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
        let(:types_de_champ_public) { [{ type: :rnf }] }
        let(:champs_public_attributes) do
          {
            first_champ.public_id => { external_id: '075-FDD-00003-01' },
          }
        end

        before do
          expect_any_instance_of(Champ).to receive(:fetch_external_data_later)
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
      let (:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :decimal_number }]) }
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

      let(:types_de_champ_public) { [{ type: :text }, { type: :integer_number }] }
      let(:text_champ) { dossier.project_champs_public.first }
      let(:number_champ) { dossier.project_champs_public.last }
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
      let(:types_de_champ_public) do
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
        champs = dossier.project_champs
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
  end

  describe '#update en_construction (stream)' do
    before { sign_in(user) }

    let(:types_de_champ_public) { [{}, { type: :piece_justificative }] }
    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let!(:dossier) { create(:dossier, :en_construction, user:, procedure:) }
    let(:first_champ) { dossier.project_champs_public.first }
    let(:first_champ_user_buffer) { dossier.with_update_stream(dossier.user) { dossier.project_champs_public.first } }
    let(:piece_justificative_champ) { dossier.project_champs_public.last }
    let(:piece_justificative_champ_user_buffer) { dossier.with_update_stream(dossier.user) { dossier.project_champs_public.last } }
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

    context 'when dossier can be updated by the owner' do
      it 'updates the champs' do
        subject
        dossier.reload
        expect(dossier.user_buffer_changes?).to be_truthy
        expect(first_champ_user_buffer.stream).to eq(Champ::USER_BUFFER_STREAM)
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
          expect(piece_justificative_champ_user_buffer.stream).to eq(Champ::USER_BUFFER_STREAM)
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
        let(:types_de_champ_public) { [{ type: :iban }] }
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
      let(:types_de_champ_public) { [{ type: :phone }] }
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
      let(:types_de_champ_public) do
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
  end

  describe '#index' do
    before { sign_in(user) }

    context 'when the user does not have any dossiers' do
      before { get(:index) }

      it { expect(assigns(:statut)).to eq('en-cours') }
    end

    context 'when the user only have its own dossiers' do
      let!(:own_dossier) { create(:dossier, user: user) }

      before { get(:index) }
      it do
        expect(assigns(:statut)).to eq('en-cours')
        expect(assigns(:user_dossiers)).to match([own_dossier])
      end
    end

    context 'when the user only have some dossiers invites' do
      let!(:invite) { create(:invite, dossier: create(:dossier), user: user) }

      before { get(:index) }

      it do
        expect(assigns(:statut)).to eq('dossiers-invites')
        expect(assigns(:dossiers_invites)).to match([invite.dossier])
      end
    end

    context 'when the user has dossiers invites, own and traites' do
      let!(:procedure) { create(:procedure, :published) }
      let!(:own_dossier) { create(:dossier, user: user) }
      let!(:own_dossier2) { create(:dossier, user: user, state: "accepte", procedure: procedure) }
      let!(:invite) { create(:invite, dossier: create(:dossier), user: user) }

      context 'and there is no statut param' do
        before { get(:index) }

        it { expect(assigns(:statut)).to eq('en-cours') }
      end

      context 'and there is "dossiers-invites" param' do
        before { get(:index, params: { statut: 'dossiers-invites' }) }

        it { expect(assigns(:statut)).to eq('dossiers-invites') }
      end

      context 'and there is "en-cours" param' do
        before { get(:index, params: { statut: 'en-cours' }) }

        it { expect(assigns(:statut)).to eq('en-cours') }
      end

      context 'and there is "traites" param' do
        before { get(:index, params: { statut: 'traites' }) }

        it { expect(assigns(:statut)).to eq('traites') }
      end

      context 'and the traité dossier has been hidden by user' do
        before do
          own_dossier2.update!(hidden_by_user_at: Time.zone.now)
          get(:index, params: { statut: 'traites' })
        end
        it { expect(assigns(:statut)).to eq('en-cours') }
      end

      context 'when the instructeur archive the dossier' do
        before do
          own_dossier2.update!(archived: true)
          get(:index, params: { statut: 'en-cours' })
        end
        it do
          expect(assigns(:statut)).to eq('en-cours')
          expect(assigns(:dossiers_traites).map(&:id)).to eq([own_dossier2.id])
          expect(own_dossier2.archived).to be_truthy
        end
      end
    end

    context 'when the user has dossier in brouillon recently updated' do
      let!(:own_dossier) { create(:dossier, user: user) }
      let!(:own_dossier_2) { create(:dossier, user: user) }

      before { get(:index) }

      it { expect(assigns(:first_brouillon_recently_updated)).to match(own_dossier_2) }
    end

    describe 'sort order' do
      before do
        travel_to(4.days.ago) { create(:dossier, user: user) }
        travel_to(2.days.ago) { create(:dossier, user: user) }
        travel_to(4.days.ago) { create(:invite, dossier: create(:dossier), user: user) }
        travel_to(2.days.ago) { create(:invite, dossier: create(:dossier), user: user) }
        get(:index)
      end

      it 'displays the most recently updated dossiers first' do
        expect(assigns(:user_dossiers).first.updated_at.to_date).to eq(2.days.ago.to_date)
        expect(assigns(:user_dossiers).second.updated_at.to_date).to eq(4.days.ago.to_date)
        expect(assigns(:dossiers_invites).first.updated_at.to_date).to eq(2.days.ago.to_date)
        expect(assigns(:dossiers_invites).second.updated_at.to_date).to eq(4.days.ago.to_date)
      end
    end

    context 'when the user has a deleted dossier on a discarded procedure' do
      render_views

      let!(:deleted_dossier) { create(:deleted_dossier, user_id: user.id) }

      before { deleted_dossier.procedure.discard! }

      subject { get(:index, params: { statut: 'dossiers-supprimes-definitivement' }) }

      it { is_expected.to have_http_status(200) }
    end
  end

  describe '#show' do
    before do
      sign_in(user)
    end

    context 'with default output' do
      subject! { get(:show, params: { id: dossier.id }) }

      context 'when the dossier is a brouillon' do
        let(:dossier) { create(:dossier, user: user) }
        it { is_expected.to redirect_to(brouillon_dossier_path(dossier)) }
      end

      context 'when the dossier has been submitted' do
        let(:dossier) { create(:dossier, :en_construction, user: user) }
        it do
          expect(assigns(:dossier)).to eq(dossier)
          is_expected.to render_template(:show)
        end
      end
    end

    context "with PDF output" do
      let(:procedure) { create(:procedure) }
      let(:dossier) do
        create(:dossier,
          :accepte,
          :with_populated_champs,
          :with_motivation,
          :with_commentaires,
          procedure: procedure,
          user: user)
      end

      subject! { get(:show, params: { id: dossier.id, format: :pdf }) }

      context 'when the dossier is a brouillon' do
        let(:dossier) { create(:dossier, user: user) }
        it { is_expected.to redirect_to(brouillon_dossier_path(dossier)) }
      end

      context 'when the dossier has been submitted' do
        it do
          expect(assigns(:acls)).to eq(PiecesJustificativesService.new(user_profile: user, export_template: nil).acl_for_dossier_export(dossier.procedure))
          expect(response).to render_template('dossiers/show')
        end
      end
    end
  end

  describe '#formulaire' do
    let(:dossier) { create(:dossier, :en_construction, user: user) }

    before do
      sign_in(user)
    end

    subject! { get(:demande, params: { id: dossier.id }) }

    it do
      expect(assigns(:dossier)).to eq(dossier)
      is_expected.to render_template(:demande)
    end
  end

  describe "#create_commentaire" do
    let(:instructeur_with_instant_message) { create(:instructeur) }
    let(:instructeur_without_instant_message) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure, user: user) }
    let(:saved_commentaire) { dossier.commentaires.first }
    let(:body) { "avant\napres" }
    let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
    let(:scan_result) { true }
    let(:now) { Time.zone.parse("18/09/1981") }

    subject {
      post :create_commentaire, params: {
        id: dossier.id,
        commentaire: {
          body: body,
          piece_jointe: file,
        },
      }
    }

    before do
      travel_to(now)
      sign_in(user)
      allow(ClamavService).to receive(:safe_file?).and_return(scan_result)
      allow(DossierMailer).to receive(:notify_new_commentaire_to_instructeur).and_return(double(deliver_later: nil))
      instructeur_with_instant_message.follow(dossier)
      instructeur_without_instant_message.follow(dossier)
      create(:instructeurs_procedure, instructeur: instructeur_with_instant_message, procedure: procedure, instant_email_new_message: true)
      create(:instructeurs_procedure, instructeur: instructeur_without_instant_message, procedure: procedure, instant_email_new_message: false)
      another_procedure = create(:procedure, instructeurs: [instructeur_without_instant_message])
      instructeur_without_instant_message.follow(create(:dossier, :en_construction, user: user, procedure: another_procedure))
      create(:instructeurs_procedure, instructeur: instructeur_without_instant_message, procedure: create(:procedure), instant_email_new_message: true)
    end

    context 'commentaire creation' do
      it "creates a commentaire" do
        expect { subject }.to change(Commentaire, :count).by(1)

        expect(response).to redirect_to(messagerie_dossier_path(dossier))
        expect(DossierMailer).to have_received(:notify_new_commentaire_to_instructeur).with(dossier, instructeur_with_instant_message.email)
        expect(DossierMailer).not_to have_received(:notify_new_commentaire_to_instructeur).with(dossier, instructeur_without_instant_message.email)
        expect(flash.notice).to be_present
        expect(dossier.reload.last_commentaire_updated_at).to eq(now)
      end

      context 'when dossier is marked as waiting for response' do
        let(:instructeur_message) { create(:commentaire, dossier: dossier, instructeur: instructeur_with_instant_message) }
        let!(:pending_response) { create(:dossier_pending_response, dossier: dossier, commentaire: instructeur_message) }
        let!(:notification) { create(:dossier_notification, instructeur: instructeur_with_instant_message, dossier:, notification_type: :attente_reponse) }

        it "marks pending response as responded when user responds" do
          expect {
            subject
          }.to change { pending_response.reload.responded_at }.from(nil)
        end

        it "removes attente_reponse notification when user responds" do
          expect {
            subject
          }.to change { DossierNotification.where(dossier: dossier, notification_type: :attente_reponse).count }.to(0)
        end
      end
    end

    context 'notify on new message to experts' do
      let(:expert) { create(:expert) }
      let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure, notify_on_new_message: true) }
      let(:avis) { create(:avis, dossier: dossier, claimant: instructeur_with_instant_message, experts_procedure: experts_procedure) }
      let(:avis2) { create(:avis, dossier: dossier, claimant: instructeur_with_instant_message, experts_procedure: experts_procedure) }

      context 'when notify_on_new_message is true' do
        before do
          allow(AvisMailer).to receive(:notify_new_commentaire_to_expert).and_return(double(deliver_later: nil))
          avis
          avis2
          subject
        end

        it 'sends just one email to the expert linked to several avis on the same dossier' do
          expect(AvisMailer).to have_received(:notify_new_commentaire_to_expert).with(dossier, avis, expert).once
        end
      end

      context 'when notify_on_new_message is false' do
        let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure, notify_on_new_message: false) }

        before do
          allow(AvisMailer).to receive(:notify_new_commentaire_to_expert).and_return(double(deliver_later: nil))
          avis
          avis2
          subject
        end

        it 'does not send any email to the expert' do
          expect(AvisMailer).not_to have_received(:notify_new_commentaire_to_expert)
        end
      end
    end

    context "when there are instructeurs who want a badge notification :message" do
      let!(:instructeur_without_message_badge) { create(:instructeur) }
      let!(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur_with_instant_message, instructeur_without_instant_message, instructeur_without_message_badge]) }

      before do
        dossier.update(groupe_instructeur:)
      end

      it "create message notification only for instructeur follower" do
        expect { subject }.to change(DossierNotification, :count).by(2)

        notifications = DossierNotification.where(
          dossier_id: dossier.id,
          notification_type: :message
        )

        expect(notifications.pluck(:instructeur_id)).to match_array([
          instructeur_with_instant_message.id,
          instructeur_without_instant_message.id,
        ])
      end
    end
  end

  describe '#notify_owner_for_changes' do
    let(:owner) { create(:user) }
    let(:invite) { create(:user) }
    let(:dossier) { create(:dossier, user: owner) }

    let(:mailer_double) { double(deliver_later: true) }

    subject do
      post :notify_owner_for_changes, params: { id: dossier.id }
    end

    before do
      sign_in(invite)

      create(:invite, dossier: dossier, user: invite)
      allow(DossierMailer)
        .to receive(:notify_owner_for_changes)
        .and_return(mailer_double)
    end

    it 'send an email to the owner with 30 min delay and redirects to brouillon' do
      subject

      expect(DossierMailer).to have_received(:notify_owner_for_changes)
        .with(dossier, invite)

      expect(mailer_double).to have_received(:deliver_later)
        .with(wait: 30.minutes)

      expect(flash.notice).to be_present
      expect(response).to redirect_to(brouillon_dossier_path(dossier))
    end

    context 'when dossier is en construction' do
      before do
        dossier.update!(state: :en_construction)
      end
      it 'redirects to modifier' do
        subject
        expect(response).to redirect_to(modifier_dossier_path(dossier))
      end
    end
  end

  describe "#papertrail" do
    before { sign_in(user) }

    subject do
      get :papertrail, format: :pdf, params: { id: dossier.id }
    end

    context 'when the dossier has been submitted' do
      let(:dossier) { create(:dossier, :en_construction, user: user) }

      it 'renders a PDF document' do
        subject
        expect(response).to render_template(:papertrail)
      end
    end

    context 'when the dossier is still a draft' do
      let(:dossier) { create(:dossier, :brouillon, user: user) }

      it 'raises an error' do
        expect { subject }.to raise_error(ActionController::BadRequest)
      end
    end
  end

  describe '#destroy' do
    before { sign_in(user) }

    subject { delete :destroy, params: { id: dossier.id } }

    shared_examples_for "the dossier can not be deleted" do
      it "doesn’t notify the deletion" do
        expect(DossierMailer).not_to receive(:notify_en_construction_deletion_to_administration)
        subject
      end

      it "doesn’t delete the dossier" do
        subject
        expect(Dossier.find_by(id: dossier.id)).not_to eq(nil)
        expect(dossier.procedure.deleted_dossiers.count).to eq(0)
      end
    end

    context 'when dossier is owned by signed in user' do
      let(:procedure) { create(:procedure) }
      let(:dossier) { create(:dossier, :en_construction, groupe_instructeur:, user:, autorisation_donnees: true) }
      let(:groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }
      let(:instructeur) { create(:instructeur) }

      before do
        instructeur.followed_dossiers << dossier
      end

      it "notifies the instructeur of the deletion" do
        expect(DossierMailer).to receive(:notify_en_construction_deletion_to_administration).with(kind_of(Dossier), instructeur.email).and_return(double(deliver_later: nil))
        subject
      end

      it "hide the dossier and does not create a deleted dossier" do
        procedure = dossier.procedure
        dossier_id = dossier.id
        subject
        expect(Dossier.find_by(id: dossier_id)).to be_present
        expect(Dossier.find_by(id: dossier_id).hidden_by_user_at).to be_present
        expect(procedure.deleted_dossiers.count).to eq(0)
      end

      it "fill hidden by reason" do
        subject
        expect(dossier.reload.hidden_by_reason).not_to eq(nil)
        expect(dossier.reload.hidden_by_reason).to eq("user_request")
      end

      it { is_expected.to redirect_to(dossiers_path) }

      context "and the instruction has started" do
        let(:dossier) { create(:dossier, :en_instruction, user: user, autorisation_donnees: true) }

        it_behaves_like "the dossier can not be deleted"
        it { is_expected.to redirect_to(dossiers_path) }
      end
    end

    context 'when dossier is not owned by signed in user' do
      let(:user2) { create(:user) }
      let(:dossier) { create(:dossier, user: user2, autorisation_donnees: true) }

      it_behaves_like "the dossier can not be deleted"
      it { is_expected.to redirect_to(root_path) }

      context 'but user is invited' do
        before { dossier.invites.create(user:, email: user.email, message: 'Salut', email_sender: user2.email) }

        it do
          procedure = dossier.procedure
          dossier_id = dossier.id

          expect(user.invite?(dossier)).to be_truthy
          is_expected.to redirect_to(dossiers_path)
          expect(Dossier.find_by(id: dossier_id)).to be_present
          expect(Dossier.find_by(id: dossier_id).hidden_by_user_at).to be_nil
          expect(procedure.deleted_dossiers.count).to eq(0)
          expect(user.invite?(dossier)).to be_falsy
        end
      end
    end
  end

  describe '#restore' do
    before { sign_in(user) }
    subject { patch :restore, params: { id: dossier.id } }

    context 'when the user want to restore his dossier' do
      let!(:dossier) { create(:dossier, :accepte, :with_individual, en_construction_at: Time.zone.yesterday.beginning_of_day.utc, hidden_by_user_at: Time.zone.yesterday.beginning_of_day.utc, user: user, autorisation_donnees: true) }

      before { subject }

      it 'must have hidden_by_user_at nil' do
        expect(dossier.reload.hidden_by_user_at).to be_nil
      end
    end
  end

  describe '#new' do
    let(:procedure) { create(:procedure, :published) }
    let(:procedure_id) { procedure.id }
    let(:params) { { procedure_id: procedure_id } }

    subject { get :new, params: params }

    it 'clears the stored procedure context' do
      subject
      expect(controller.stored_location_for(:user)).to be nil
    end

    context 'when params procedure_id is present' do
      context 'when procedure_id is valid' do
        context 'when user is logged in' do
          before do
            sign_in user
          end

          it { is_expected.to have_http_status(302) }
          it { expect { subject }.to change(Dossier, :count).by 1 }
          context 'when procedure is for entreprise' do
            it { is_expected.to redirect_to siret_dossier_path(id: Dossier.last) }
          end

          context 'when procedure is for particulier' do
            let(:procedure) { create(:procedure, :published, :for_individual) }
            it { is_expected.to redirect_to identite_dossier_path(id: Dossier.last) }
          end

          context 'when procedure is closed' do
            let(:procedure) { create(:procedure, :closed) }

            it { is_expected.to redirect_to dossiers_path }
          end
        end
        context 'when user is not logged' do
          it do
            is_expected.to have_http_status(302)
            is_expected.to redirect_to new_user_session_path
          end
        end
      end

      context 'when procedure_id is not valid' do
        let(:procedure_id) { 0 }

        before do
          sign_in user
        end

        it { is_expected.to redirect_to dossiers_path }
      end

      context 'when procedure is not published' do
        let(:procedure) { create(:procedure) }

        before do
          sign_in user
        end

        it { is_expected.to redirect_to dossiers_path }

        context 'and brouillon param is passed' do
          subject { get :new, params: { procedure_id: procedure_id, brouillon: true } }

          it do
            is_expected.to have_http_status(302)
            is_expected.to redirect_to siret_dossier_path(id: Dossier.last)
          end
        end
      end
    end
  end

  describe "#dossier_for_help" do
    before do
      sign_in(user)
      controller.params[:dossier_id] = dossier_id.to_s
    end

    subject { controller.dossier_for_help }

    context 'when the id matches an existing dossier' do
      let(:dossier) { create(:dossier) }
      let(:dossier_id) { dossier.id }

      it { is_expected.to eq dossier }
    end

    context 'when the id doesn’t match an existing dossier' do
      let(:dossier_id) { 9999999 }
      it { is_expected.to be nil }
    end

    context 'when the id is empty' do
      let(:dossier_id) { nil }
      it { is_expected.to be_falsy }
    end
  end

  describe '#index' do
    before do
      sign_in(user)
    end
    it 'works' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#extend_conservation' do
    let(:procedure) { create(:procedure, duree_conservation_dossiers_dans_ds: 3) }
    let(:dossier) { create(:dossier, :en_construction, procedure:, user:) }
    subject { post :extend_conservation, params: { dossier_id: dossier.id } }
    context 'when user logged in' do
      before { sign_in(user) }
      it 'works' do
        expect(subject).to redirect_to(dossier_path(dossier))
      end

      it 'extends conservation_extension by duree_conservation_dossiers_dans_ds' do
        subject
        expect(dossier.reload.conservation_extension).to eq(procedure.duree_conservation_dossiers_dans_ds.months)
      end

      it 'updates expired_at' do
        expired_at = dossier.expired_at
        subject
        expect(dossier.reload.expired_at).to be_within(1.hour).of(expired_at + 3.months)
      end

      it 'flashed notice success' do
        subject
        expect(flash[:notice]).to eq(I18n.t('views.users.dossiers.archived_dossier', duree_conservation_dossiers_dans_ds: procedure.duree_conservation_dossiers_dans_ds))
      end
    end

    context 'when not logged in' do
      it 'fails' do
        subject
        expect { expect(response).to redirect_to(new_user_session_path) }
      end
    end
  end

  describe '#clone' do
    let(:dossier) { create(:dossier, procedure: procedure) }
    subject { post :clone, params: { id: dossier.id } }

    context 'not signed in' do
      let(:procedure) { create(:procedure) }

      it { expect(subject).to redirect_to(new_user_session_path) }
    end

    context 'signed with user dossier' do
      let(:procedure) { create(:procedure, :with_all_champs) }

      before { sign_in dossier.user }

      it { expect(subject).to redirect_to(brouillon_dossier_path(Dossier.last)) }
      it { expect { subject }.to change { dossier.user.dossiers.count }.by(1) }
    end
  end

  describe '#champ' do
    let(:stable_id) { generate(:stable_id) }
    let(:types_de_champ_public) { [{ type: :text, stable_id: }] }
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:, user:) }
    let(:champ) { dossier.champs.first }

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

    context 'when champ is pollable' do
      let(:referentiel) { create(:api_referentiel, :exact_match) }
      let(:types_de_champ_public) { [{ type: :referentiel, referentiel:, stable_id: }] }

      context 'when the requested external_id had not been fetched' do
        before { dossier.champs.first.update_columns(external_id: 'kthxbye') }

        it 'does not validates errors' do
          subject
          expect(response).not_to include('Aucun résultat ne correspond à votre recherche.')
        end
      end

      context 'when the requested external_id had been fetched' do
        before { dossier.champs.find(&:referentiel?).update_columns(external_id: 'kthxbye', value: "OK", data: {}) }
        it 'validates errors' do
          subject
          expect(response).not_to include('Référence trouvée : OK')
        end

        context 'propagation du prefill (polling)' do
          render_views
          let(:referentiel) { create(:api_referentiel, :exact_match) }
          let(:referentiel_stable_id) { 1 }
          let(:types_de_champ_public) do
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
            dossier.champs.find(&:referentiel?).update_external_data!(data: { ok: 'valeur préremplie', repetition: [{ nom: 'Jeanne' }, { nom: "Bob" }, {}] })

            get :champ, params: { id: dossier.id, stable_id: referentiel_stable_id }, format: :turbo_stream

            expect(assigns(:to_update).size).to eq(3)
            expect(dossier.reload.project_champs.map(&:value)).to include('valeur préremplie')
            expect(response.body).to include('Donnée remplie automatiquement.')
            expect(response.body).to include('Jeanne')
            expect(response.body).to include('Bob')
          end
        end
      end

      context 'when the requested external_id is in error' do
        before { dossier.champs.first.update_columns(external_id: 'kthxbye', value: "OK", fetch_external_data_exceptions: [ExternalDataException.new(error: "thxbye", code: 429)]) }
        it 'validates errors' do
          subject
          expect(response).not_to include('Trop de demandes. Nous réessayons pour vous.')
        end
      end
    end
  end

  describe '#show' do
    let(:dossier) { create(:dossier, :en_construction, user: user) }

    before { sign_in(user) }

    context 'when dossier is in trash' do
      before { dossier.hide_and_keep_track!(user, :user_request) }

      it 'redirects to trash page' do
        get :show, params: { id: dossier.id }
        expect(response).to redirect_to(corbeille_dossier_path(dossier.id))
      end
    end

    context 'when dossier is deleted' do
      before do
        dossier.destroy
        create(:deleted_dossier, dossier_id: dossier.id, user_id: user.id)
      end

      it 'redirects to deleted page' do
        get :show, params: { id: dossier.id }
        expect(response).to redirect_to(supprime_dossier_path(dossier.id))
      end
    end

    context 'when dossier not found' do
      it 'raises not found' do
        expect { get :show, params: { id: 42 } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'pro_connect_restriction' do
    let(:user) { create(:user) }
    let(:procedure) { create(:procedure, :for_individual, :published, pro_connect_restriction: :all) }
    let(:brouillon) { create(:dossier, :brouillon, user:, procedure:) }

    before { sign_in user }

    context 'when user is ProConnected' do
      before do
        cookies.encrypted[:pro_connect_session_info] = { user_id: user.id }.to_json
      end

      it 'allows creating a dossier' do
        post :new, params: { procedure_id: procedure.id }
        expect(response).to redirect_to(identite_dossier_path(Dossier.last))
      end

      it 'allows submitting' do
        post :submit_brouillon, params: { id: brouillon.id, dossier: {} }
        brouillon.reload
        expect(brouillon).to be_en_construction
      end
    end

    context 'when user is not ProConnected' do
      it 'does not allow create new dossier and redirects to pro_connect' do
        expect { post :new, params: { procedure_id: procedure.id } }.not_to change { Dossier.count }
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include("ProConnect")
      end

      it 'redirects to pro_connect' do
        post :submit_brouillon, params: { id: brouillon.id, dossier: {} }
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include("ProConnect")
        brouillon.reload
        expect(brouillon).to be_brouillon
      end
    end

    context 'when restriction is admin only and user is not ProConnected' do
      let(:procedure) { create(:procedure, :for_individual, :published, pro_connect_restriction: :instructeurs) }
      it 'allows creating a dossier' do
        post :new, params: { procedure_id: procedure.id }
        expect(response).to redirect_to(identite_dossier_path(Dossier.last))
      end
    end
  end

  private

  def find_champ_by_stable_id(dossier, stable_id)
    dossier.champs.joins(:type_de_champ).find_by(types_de_champ: { stable_id: stable_id })
  end
end
