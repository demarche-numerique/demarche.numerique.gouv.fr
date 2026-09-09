# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users.usager }

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

  describe 'GET #index' do
    let(:user) { create(:user) }
    before { sign_in(user) }

    it 'assigns @filter as a DossierFilterService' do
      get :index
      expect(assigns(:filter)).to be_a(Users::DossierFilterService)
    end

    it 'assigns @dossiers paginated to 25 per page' do
      create_list(:dossier, 30, :en_construction, user: user)
      get :index
      expect(assigns(:dossiers).size).to eq(25)
    end

    it 'assigns @corbeille_count' do
      create(:dossier, user: user, hidden_by_user_at: Time.current)
      create(:dossier, user: user, hidden_by_expired_at: Time.current)
      get :index
      expect(assigns(:corbeille_count)).to eq(2)
    end

    it 'assigns @pending_transfers_count' do
      get :index
      expect(assigns(:pending_transfers_count)).to be_a(Integer)
    end

    context 'user buffer changes prefilter' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{}]) }
      let!(:dossier_with_changes) { create(:dossier, :en_construction, user:, procedure:) }
      let!(:dossier_without_changes) { create(:dossier, :en_construction, user:, procedure:) }
      let!(:dossier_brouillon) { create(:dossier, user:, procedure:) }

      before do
        dossier_with_changes.with_update_stream(user) do
          dossier_with_changes
            .champ_for_update(dossier_with_changes.revision.public_root_type_de_champs.first, updated_by: user.email)
            .update!(value: 'nouvelle valeur')
        end
      end

      it 'flags only en_construction dossiers with unsubmitted user changes' do
        get :index
        expect(assigns(:dossier_ids_with_user_buffer_changes)).to eq(Set[dossier_with_changes.id])
      end
    end

    context 'filter panel-only request' do
      before { create_list(:dossier, 6, :en_construction, user: user) }

      it 'skips the dossier list workload when the filter_panel param is set' do
        get :index, params: { filter_panel: '1' }
        expect(assigns(:filter)).to be_present
        expect(assigns(:procedures_for_select)).to be_present
        expect(assigns(:dossiers)).to be_nil
        expect(assigns(:total_count)).to be_nil
      end

      it 'renders the dossier list for a normal request (no filter_panel param)' do
        get :index
        expect(assigns(:dossiers)).to be_present
      end
    end

    context 'simple list threshold' do
      it 'shows the simple list with up to 5 dossiers' do
        create_list(:dossier, 5, :en_construction, user: user)
        get :index
        expect(assigns(:show_simple_list)).to be(true)
      end

      it 'shows the full list (search and filters) from 6 dossiers' do
        create_list(:dossier, 6, :en_construction, user: user)
        get :index
        expect(assigns(:show_simple_list)).to be(false)
      end
    end

    context 'personnalisation link' do
      before { Flipper.enable(:dossiers_list_personnalisation, user) }

      it 'shows the link for a user above the threshold through invitations only' do
        create_list(:dossier, 6, :en_construction).each do |dossier|
          create(:invite, dossier:, user:)
        end
        get :index
        expect(assigns(:show_personnalisation_link)).to be(true)
      end
    end

    it 'passes filter params to the service' do
      get :index, params: { state: ['en_construction'], alert: ['a_corriger'], procedure_id: '42' }
      expect(assigns(:filter)).to be_a(Users::DossierFilterService)
      expect(response).to have_http_status(:ok)
    end

    context 'cross-user isolation' do
      let!(:own_dossier) { create(:dossier, :en_construction, user: user) }
      let!(:other_user_dossier) { create(:dossier, :en_construction) }

      it 'does not list another user dossiers' do
        get :index
        expect(assigns(:dossiers)).to include(own_dossier)
        expect(assigns(:dossiers)).not_to include(other_user_dossier)
      end

      it 'does not return another user dossier when searching by its id' do
        get :index, params: { search: other_user_dossier.id.to_s }
        expect(assigns(:dossiers)).not_to include(other_user_dossier)
      end
    end

    context '#procedures_for_select' do
      let(:procedure_a) { create(:procedure, libelle: 'Alpha') }
      let(:procedure_b) { create(:procedure, libelle: 'Bêta') }
      let(:procedure_c) { create(:procedure, libelle: 'Gamma') }

      it 'returns procedures from user dossiers and invitations sorted by libelle' do
        create_list(:dossier, 6, :en_construction, user: user, procedure: procedure_a)
        invited_dossier = create(:dossier, :en_construction, procedure: procedure_b)
        create(:invite, dossier: invited_dossier, user: user)
        create(:dossier, :en_construction, procedure: procedure_c)

        get :index

        expect(assigns(:procedures_for_select)).to eq([['Alpha', procedure_a.id], ['Bêta', procedure_b.id]])
      end

      it 'excludes procedures from invited dossiers hidden by the user' do
        create_list(:dossier, 6, :en_construction, user: user, procedure: procedure_a)
        hidden_invited = create(:dossier, :en_construction, procedure: procedure_b, hidden_by_user_at: Time.current)
        create(:invite, dossier: hidden_invited, user: user)

        get :index

        expect(assigns(:procedures_for_select)).to eq([['Alpha', procedure_a.id]])
      end

      it 'is empty in simple list mode (no filters shown)' do
        create(:dossier, :en_construction, user: user, procedure: procedure_a)

        get :index

        expect(assigns(:show_simple_list)).to be(true)
        expect(assigns(:procedures_for_select)).to eq([])
      end
    end
  end

  describe '#show' do
    before do
      sign_in(user)
    end

    context 'with default output' do
      subject! { get(:show, params: { id: dossier.id }) }

      context 'when the dossier is a brouillon' do
        let(:dossier) { dossiers.brouillon }
        it { is_expected.to redirect_to(brouillon_dossier_path(dossier)) }
      end

      context 'when the dossier has been submitted' do
        let(:dossier) { dossiers.en_construction }
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
        let(:dossier) { dossiers.brouillon }
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
    let(:dossier) { dossiers.en_construction }

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
    let(:procedure) { procedures.individual }
    # fresh dossier (not the seeded one): saved_commentaire below picks the first commentaire
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

  describe "#attestation_depot" do
    before { sign_in(user) }

    subject do
      get :attestation_depot, format: :pdf, params: { id: dossier.id }
    end

    context 'when the dossier has been submitted' do
      let(:dossier) { dossiers.en_construction }

      before do
        allow(WeasyprintService).to receive(:generate_pdf).and_return("%PDF-1.4 fake")
      end

      it 'sends a PDF document' do
        subject
        expect(response.headers['Content-Type']).to include('application/pdf')
      end

      it 'calls WeasyPrint with the correct context' do
        subject
        expect(WeasyprintService).to have_received(:generate_pdf)
          .with(a_string_matching(/#{dossier.procedure.libelle}/), { procedure_id: dossier.procedure.id, dossier_id: dossier.id })
      end

      it 'includes dossier identity in the HTML' do
        subject
        expect(WeasyprintService).to have_received(:generate_pdf)
          .with(a_string_matching(/#{dossier.individual.prenom}/), anything)
      end
    end

    context 'when the dossier is still a draft' do
      let(:dossier) { dossiers.brouillon }

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
        let(:dossier) { dossiers.en_instruction }

        it_behaves_like "the dossier can not be deleted"
        it { is_expected.to redirect_to(dossiers_path) }
      end
    end

    context 'when dossier is not owned by signed in user' do
      let(:user2) { create(:user) }
      let(:dossier) { create(:dossier, user: user2, autorisation_donnees: true, procedure: procedures.individual) }

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

  describe '#set_accuse_lecture_agreement_at' do
    let(:dossier) { dossiers.en_instruction }

    before { sign_in(user) }

    it 'updates accuse_lecture_agreement_at' do
      expect { post :set_accuse_lecture_agreement_at, params: { id: dossier.id } }
        .to change { dossier.reload.accuse_lecture_agreement_at }.from(nil)
    end
  end

  describe '#restore' do
    before { sign_in(user) }
    subject { patch :restore, params: { id: dossier.id } }

    context 'when the user want to restore his dossier' do
      let!(:dossier) { create(:dossier, :accepte, :with_individual, en_construction_at: Time.zone.yesterday.beginning_of_day.utc, hidden_by_user_at: Time.zone.yesterday.beginning_of_day.utc, user: user, autorisation_donnees: true, procedure: procedures.individual) }

      before { subject }

      it 'must have hidden_by_user_at nil' do
        expect(dossier.reload.hidden_by_user_at).to be_nil
      end
    end
  end

  describe '#new' do
    let(:procedure) { procedures.entreprise }
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
            allow(Ami::CreateNotificationService).to receive(:call)
          end

          it { is_expected.to have_http_status(302) }
          it { expect { subject }.to change(Dossier, :count).by 1 }
          context 'when procedure is for entreprise' do
            it { is_expected.to redirect_to siret_dossier_path(id: Dossier.last) }
          end

          context 'when procedure is for particulier' do
            let(:procedure) { procedures.individual }
            it { is_expected.to redirect_to identite_dossier_path(id: Dossier.last) }
          end

          it 'enqueues AMI notification for created draft' do
            subject

            expect(Ami::CreateNotificationService).to have_received(:call).with(dossier: Dossier.last)
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

    context 'when the id matches a dossier owned by the current user' do
      let(:dossier) { dossiers.brouillon }
      let(:dossier_id) { dossier.id }

      it { is_expected.to eq dossier }
    end

    context 'when the id matches a dossier the current user was invited to' do
      let(:dossier) { create(:dossier) }
      let(:dossier_id) { dossier.id }
      before { create(:invite, dossier:, user:) }

      it { is_expected.to eq dossier }
    end

    context 'when the id matches a dossier from another user' do
      let(:other_user) { create(:user) }
      let(:other_dossier) { create(:dossier, user: other_user) }
      let(:dossier_id) { other_dossier.id }

      it { is_expected.to be nil }
    end

    context 'when the id doesn’t match an existing dossier' do
      let(:dossier_id) { 9999999 }
      it { is_expected.to be nil }
    end

    context 'when the id is empty' do
      let(:dossier_id) { nil }
      it { is_expected.to be nil }
    end
  end

  describe '#extend_conservation' do
    let(:procedure) { procedures.individual }
    let(:dossier) { create(:dossier, procedure:, user:) }
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

      before do
        sign_in dossier.user
        allow(Ami::CreateNotificationService).to receive(:call)
      end

      it { expect(subject).to redirect_to(brouillon_dossier_path(Dossier.last)) }
      it { expect { subject }.to change { dossier.user.dossiers.count }.by(1) }

      it 'enqueues AMI notification' do
        subject

        expect(Ami::CreateNotificationService).to have_received(:call).with(dossier: Dossier.last)
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
      it 'does not allow create new dossier and redirects to pro_connect_required' do
        expect { post :new, params: { procedure_id: procedure.id } }.not_to change { Dossier.count }
        expect(response).to redirect_to(pro_connect_required_path)
        expect(flash[:alert]).to include("ProConnect")
      end

      it 'redirects to pro_connect_required' do
        post :submit_brouillon, params: { id: brouillon.id, dossier: {} }
        expect(response).to redirect_to(pro_connect_required_path)
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

  describe 'GET #transfer_requests' do
    let(:user) { create(:user, email: 'destinataire@example.com') }
    before { sign_in(user) }

    let(:expediteur) { create(:user) }

    it 'assigns dossiers transferred to user email' do
      dossier = create(:dossier, :en_construction, user: expediteur)
      transfer = DossierTransfer.create(email: 'destinataire@example.com', dossiers: [dossier])
      dossier.update!(dossier_transfer_id: transfer.id)

      get :transfer_requests
      expect(assigns(:pending_transfers)).to include(dossier)
    end

    it 'excludes dossiers transferred to other emails' do
      other_dossier = create(:dossier, :en_construction, user: expediteur)
      transfer = DossierTransfer.create(email: 'autre@example.com', dossiers: [other_dossier])
      other_dossier.update!(dossier_transfer_id: transfer.id)

      get :transfer_requests
      expect(assigns(:pending_transfers)).not_to include(other_dossier)
    end

    it 'is accessible without ownership restriction' do
      get :transfer_requests
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #trash' do
    let(:user) { create(:user) }
    before { sign_in(user) }

    it 'assigns dossiers hidden by user or expired' do
      hidden_by_user = create(:dossier, :en_construction, user: user, hidden_by_user_at: Time.current)
      hidden_by_expired = create(:dossier, :en_construction, user: user, hidden_by_expired_at: Time.current)
      visible = create(:dossier, :en_construction, user: user)

      get :trash

      expect(assigns(:dossiers)).to include(hidden_by_user, hidden_by_expired)
      expect(assigns(:dossiers)).not_to include(visible)
    end

    it 'paginates dossiers' do
      create_list(:dossier, 30, :en_construction, user: user, hidden_by_user_at: Time.current)
      get :trash
      expect(assigns(:dossiers).size).to eq(25)
    end

    it 'is accessible without ownership restriction' do
      get :trash
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#revert_prefill' do
    before { sign_in(user) }

    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{}]) }
    let(:dossier) { create(:dossier, user:, procedure:) }
    let(:champ) { dossier.root_champs_public.first }

    subject { patch :revert_prefill, params: { id: dossier.id, stable_id: champ.stable_id }, format: :turbo_stream }

    context 'when champ has prefilled_original_value' do
      before do
        champ.update!(prefilled: true, value: 'modified', prefilled_original_value: { 'value' => 'original' })
      end

      it 'restores the original value and responds with turbo_stream' do
        subject
        expect(champ.reload.value).to eq('original')
        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'when champ has no prefilled_original_value' do
      before { champ.update!(value: 'some_value') }

      it 'does not change the value' do
        subject
        expect(champ.reload.value).to eq('some_value')
        expect(response).to have_http_status(:success)
      end
    end

    context 'when dossier is en_construction (buffer stream)' do
      let(:dossier) { create(:dossier, :en_construction, user:, procedure:) }

      before do
        champ.update!(prefilled: true, value: 'modified', prefilled_original_value: { 'value' => 'original' })
      end

      it 'reverts on the buffer stream champ and responds with turbo_stream' do
        subject
        dossier.reload
        buffer_champ = dossier.with_update_stream(user) { dossier.root_champs_public.first }
        expect(buffer_champ.value).to eq('original')
        expect(buffer_champ.prefilled_original_value).to eq({ 'value' => 'original' })
        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'when dossier is not editable (en_instruction)' do
      let(:dossier) { create(:dossier, :en_instruction, user:, procedure:) }

      it 'redirects' do
        subject
        expect(response).to redirect_to(dossier_path(dossier))
      end
    end
  end

  private

  def find_champ_by_stable_id(dossier, stable_id)
    dossier.champ_data.joins(:type_de_champ).find_by(types_de_champ: { stable_id: stable_id })
  end
end
