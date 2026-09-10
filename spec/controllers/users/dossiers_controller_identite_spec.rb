# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users.usager }

  describe 'identite with FranceConnect' do
    let(:procedure) { procedures.individual }
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

  describe 'identite turbo_stream persists the persona choice' do
    let(:procedure) { procedures.individual }
    let(:dossier) { dossiers.brouillon }
    let(:now) { Time.zone.parse('01/01/2100') }

    before { sign_in(user) }

    subject do
      travel_to(now) do
        patch :identite, params: { id: dossier.id, dossier: { for_tiers: for_tiers_value } }, format: :turbo_stream
      end
    end

    # The choice must be persisted so that the identity form does not disappear on a page reload.
    context 'when choosing "pour vous"' do
      let(:for_tiers_value) { 'false' }

      it 'persists for_tiers and stamps identity_updated_at' do
        subject
        expect(dossier.reload.for_tiers).to be false
        expect(dossier.identity_updated_at).to eq(now)
      end
    end

    context 'when choosing "pour une autre personne"' do
      let(:for_tiers_value) { 'true' }

      it 'persists for_tiers and stamps identity_updated_at' do
        subject
        expect(dossier.reload.for_tiers).to be true
        expect(dossier.identity_updated_at).to eq(now)
      end
    end

    context 'when the session is connected via ProConnect' do
      # Attach the ProConnect identity to the seeded usager rather than signing in
      # another user: `dossiers.brouillon` belongs to them, and ensure_ownership!
      # would otherwise redirect before the action runs.
      before do
        create(:pro_connect_information, user:)
        allow(controller).to receive(:logged_in_with_pro_connect?).and_return(true)
      end

      context 'switching to for_tiers then back to for self' do
        it 'persists the persona choice and prefills the mandataire from ProConnect in the rendered form' do
          pc_info = user.last_pro_connect_information

          patch :identite, params: { id: dossier.id, dossier: { for_tiers: 'true' } }, format: :turbo_stream
          expect(dossier.reload.for_tiers).to be true
          # The mandataire is assigned in memory and re-rendered (persisted only on update_identite).
          expect(assigns(:dossier).mandataire_first_name).to eq(pc_info.given_name)
          expect(assigns(:dossier).mandataire_last_name).to eq(pc_info.usual_name)

          patch :identite, params: { id: dossier.id, dossier: { for_tiers: 'false' } }, format: :turbo_stream
          expect(dossier.reload.for_tiers).to be false
        end
      end
    end

    context 'when the dossier is already deposited' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, user:, procedure:) }
      let(:for_tiers_value) { 'true' }

      it 'does not persist the choice: it must change with the mandataire identity (RAILS-M9G)' do
        subject
        expect(dossier.reload.for_tiers).to be false
      end
    end
  end

  describe 'update_identite' do
    let(:procedure) { procedures.individual }
    let(:dossier) { dossiers.brouillon }

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
      let(:dossier) { dossiers.en_instruction }
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
      let(:dossier_params) { { for_tiers: 'true', individual_attributes: { gender: 'M', nom: 'Mouse', prenom: 'Mickey', email: 'mickey@gmail.com', notification_method: 'email' } } }

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
        let(:dossier_params) { { for_tiers: 'true', mandataire_first_name: "Jean", mandataire_last_name: "Dupont" } }

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

    context 'when user is connected via FranceConnect' do
      let(:user) { create(:user, :with_fci) }

      context 'when dossier is for self' do
        let(:dossier) { create(:dossier, :with_individual, user:, procedure:) }

        it 'ignores attempts to modify locked identity attributes and uses FranceConnect values' do
          fc_info = user.france_connect_informations.first

          post :update_identite, params: {
            id: dossier.id,
            dossier: {
              individual_attributes: {
                nom: 'Hacker',
                prenom: 'Evil',
              },
            },
          }

          dossier.reload
          # Identity should be locked to FranceConnect values, ignoring submitted params
          expect(dossier.individual.nom).to eq(fc_info.family_name)
          expect(dossier.individual.prenom).to eq(fc_info.given_name)
        end
      end

      context 'when dossier is for tiers' do
        let(:dossier) { create(:dossier, :for_tiers_without_notification, user:, procedure:) }

        it 'ignores attempts to modify locked mandataire fields' do
          fc_info = user.france_connect_informations.first

          post :update_identite, params: {
            id: dossier.id,
            dossier: {
              for_tiers: 'true',
              mandataire_first_name: 'Hacker',
              mandataire_last_name: 'Evil',
              individual_attributes: {
                nom: 'Beneficiaire',
                prenom: 'Le',
              },
            },
          }

          dossier.reload
          # Mandataire should be locked to FranceConnect values
          expect(dossier.mandataire_first_name).to eq(fc_info.given_name)
          expect(dossier.mandataire_last_name).to eq(fc_info.family_name)
          # Beneficiary should be updated
          expect(dossier.individual.nom).to eq('Beneficiaire')
          expect(dossier.individual.prenom).to eq('Le')
        end

        it 'prevents bypassing identity lock by omitting for_tiers param' do
          fc_info = user.france_connect_informations.first

          # Attacker tries to modify identity by omitting for_tiers param
          # This would switch dossier to "for self" mode, but identity should still be locked
          post :update_identite, params: {
            id: dossier.id,
            dossier: {
              # for_tiers is omitted - attacker trying to bypass
              individual_attributes: {
                nom: 'Hacker',
                prenom: 'Evil',
              },
            },
          }

          dossier.reload
          # Dossier switched to "for self" mode
          expect(dossier.for_tiers).to be false
          # But identity is still locked to FranceConnect values
          expect(dossier.individual.nom).to eq(fc_info.family_name)
          expect(dossier.individual.prenom).to eq(fc_info.given_name)
        end
      end
    end

    context 'when the session is connected via ProConnect' do
      let(:user) { create(:user, :with_pci) }

      before { allow(controller).to receive(:logged_in_with_pro_connect?).and_return(true) }

      context 'when dossier is for self' do
        let(:dossier) { create(:dossier, :with_individual, user:, procedure:) }

        it 'ignores attempts to modify locked nom/prenom but honours the submitted gender' do
          pc_info = user.last_pro_connect_information

          post :update_identite, params: {
            id: dossier.id,
            dossier: {
              individual_attributes: {
                nom: 'Hacker',
                prenom: 'Evil',
                gender: Individual::GENDER_FEMALE,
              },
            },
          }

          dossier.reload
          # nom/prenom locked to ProConnect values, ignoring submitted params
          expect(dossier.individual.nom).to eq(pc_info.usual_name)
          expect(dossier.individual.prenom).to eq(pc_info.given_name)
          # gender is not provided by ProConnect: the submitted value is kept
          expect(dossier.individual.gender).to eq(Individual::GENDER_FEMALE)
        end
      end

      context 'when dossier is for tiers' do
        let(:dossier) { create(:dossier, :for_tiers_without_notification, user:, procedure:) }

        it 'locks the mandataire to ProConnect values and keeps the beneficiary editable' do
          pc_info = user.last_pro_connect_information

          post :update_identite, params: {
            id: dossier.id,
            dossier: {
              for_tiers: 'true',
              mandataire_first_name: 'Hacker',
              mandataire_last_name: 'Evil',
              individual_attributes: {
                nom: 'Beneficiaire',
                prenom: 'Le',
              },
            },
          }

          dossier.reload
          expect(dossier.mandataire_first_name).to eq(pc_info.given_name)
          expect(dossier.mandataire_last_name).to eq(pc_info.usual_name)
          expect(dossier.individual.nom).to eq('Beneficiaire')
          expect(dossier.individual.prenom).to eq('Le')
        end
      end
    end

    context 'when a for_tiers dossier is updated with an arbitrary email' do
      let(:procedure) { create(:procedure, :for_individual, for_tiers_enabled: true) }
      let(:dossier) { create(:dossier, :for_tiers_without_notification, state: 'brouillon', user: user, procedure: procedure) }
      let(:other_email) { 'beneficiaire@example.com' }
      let(:dossier_params) do
        {
          for_tiers: 'true',
          individual_attributes: { gender: 'M', nom: 'Mouse', prenom: 'Mickey', email: other_email, notification_method: 'email' },
        }
      end

      it 'does not create a pre-confirmed account for the submitted email' do
        subject
        created_user = User.find_by(email: other_email)
        # The submitted email is third-party data: the resulting account must
        # not be considered email-verified or confirmed before the owner acts.
        expect(created_user).to be_present
        expect(created_user.email_verified_at).to be_nil
        expect(created_user.confirmed?).to be false
      end

      context 'when an unverified user already exists for the submitted email' do
        let!(:existing_user) do
          create(:user,
            email: other_email,
            confirmation_token: 'existing-token',
            confirmation_sent_at: 2.hours.ago,
            confirmed_at: nil)
        end

        it 'does not overwrite the existing confirmation_token' do
          expect { subject }.not_to change { existing_user.reload.confirmation_token }
        end

        it 'does not send a new invite_tiers email to the existing user' do
          expect { subject }.not_to have_enqueued_mail(UserMailer, :invite_tiers)
        end
      end
    end
  end

  describe '#siret' do
    before { sign_in(user) }
    let!(:dossier) { create(:dossier, user: user, procedure: procedures.entreprise) }

    subject { get :siret, params: { id: dossier.id } }

    it { is_expected.to render_template(:siret) }

    context 'when the session is connected via ProConnect' do
      before do
        create(:pro_connect_information, user:, siret: '12345678901234')
        allow_any_instance_of(ProConnectSessionConcern).to receive(:logged_in_with_pro_connect?).and_return(true)
      end

      context 'and the user has no siret yet' do
        before { user.update!(siret: nil) }

        it 'prefills the form with the ProConnect siret' do
          subject

          expect(assigns(:siret_prefilled_by_pro_connect)).to be(true)
          expect(controller.current_user.siret).to eq('12345678901234')
        end
      end

      context 'and the user already has a memorized siret' do
        before { user.update!(siret: '41816609600051') }

        it 'keeps the memorized siret' do
          subject

          expect(assigns(:siret_prefilled_by_pro_connect)).to be(false)
          expect(controller.current_user.siret).to eq('41816609600051')
        end
      end
    end

    context 'when the session is not connected via ProConnect' do
      before do
        create(:pro_connect_information, user:, siret: '12345678901234')
        user.update!(siret: nil)
      end

      it 'does not prefill the form' do
        subject

        expect(assigns(:siret_prefilled_by_pro_connect)).to be(false)
        expect(controller.current_user.siret).to be_nil
      end
    end
  end

  describe '#update_siret' do
    let(:dossier) { create(:dossier, user: user, procedure: procedures.entreprise) }
    let(:siret) { params_siret.delete(' ') }
    let(:siren) { siret[0..8] }
    let(:api_etablissement_status) { 200 }
    let(:api_etablissement_body) { Rails.root.join('spec/fixtures/files/api_entreprise/etablissements.json').read }
    let(:token_expired) { false }
    let(:provider_up) { true }

    before do
      sign_in(user)
      # the procedure factory sets a dummy token; the seeded procedure has none
      procedures.entreprise.update!(api_entreprise_token: JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none'))
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(status: api_etablissement_status, body: api_etablissement_body)
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles)
        .and_return(["attestations_fiscales", "attestations_sociales", "bilans_entreprise_bdf"])
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(token_expired)
      allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(provider_up)
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

        it_behaves_like 'the request fails with an error', I18n.t('errors.messages.siret.network_error')
      end

      context 'When API-Entreprise is globally down' do
        let(:api_etablissement_status) { 502 }
        let(:provider_up) { false }

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
    let(:dossier) { dossiers.avec_siret }

    before { sign_in(user) }

    subject { get :etablissement, params: { id: dossier.id } }

    it { is_expected.to render_template(:etablissement) }

    context 'when the dossier has no etablissement yet' do
      let(:dossier) { dossiers.en_construction }
      it { is_expected.to redirect_to siret_dossier_path(dossier) }
    end
  end
end
