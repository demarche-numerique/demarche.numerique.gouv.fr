# frozen_string_literal: true

describe Experts::AvisController, type: :controller do
  context 'with an expert signed in' do
    render_views

    let(:now) { Time.zone.parse('01/02/2345') }
    let(:instructeur) { create(:instructeur) }
    let(:instructeur_without_instant_avis_notification) { create(:instructeur) }
    let!(:instructeur_with_instant_avis_notification) { create(:instructeur) }
    let(:another_instructeur) { create(:instructeur) }
    let(:claimant) { create(:expert) }
    let(:expert) { create(:expert) }
    let(:types_de_champ_public) { [] }
    let(:procedure) { create(:procedure, :published, instructeurs: [instructeur, another_instructeur, instructeur_with_instant_avis_notification, instructeur_without_instant_avis_notification], types_de_champ_public:) }
    let(:procedure_id) { procedure.id }
    let(:another_procedure) { create(:procedure, :published, instructeurs: [instructeur]) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:experts_procedure) { create(:experts_procedure, expert:, procedure:) }
    let!(:avis_without_answer) { create(:avis, dossier:, claimant:, experts_procedure:) }
    let!(:avis_with_answer) { create(:avis, dossier:, claimant:, experts_procedure:, answer: 'yop') }

    let!(:revoked_procedure) { create(:procedure, :published, instructeurs: [instructeur]) }
    let!(:revoked_dossier) { create(:dossier, :en_construction, procedure: revoked_procedure) }
    let!(:revoked_experts_procedure) { create(:experts_procedure, expert: expert, procedure: revoked_procedure) }
    let!(:revoked_avis) do
      create(:avis, dossier: revoked_dossier, claimant:, experts_procedure: revoked_experts_procedure, introduction: 'revoked', revoked_at: Time.zone.now)
    end

    before do
      sign_in(expert.user)
    end

    describe '#index' do
      context 'nominal' do
        before { get :index }

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:avis_by_procedure).keys).to match_array(procedure)
          expect(assigns(:avis_by_procedure).values.flatten).to match_array([avis_without_answer, avis_with_answer])
        end
      end

      context 'avis on termine dossier' do
        let(:another_experts_procedure) { create(:experts_procedure, expert:, procedure: another_procedure) }
        let(:dossier_termine) { create(:dossier, :accepte, procedure: another_procedure) }
        let(:another_avis_without_answer) { create(:avis, claimant:, dossier: dossier_termine, experts_procedure: another_experts_procedure) }
        let(:another_avis_with_answer) { create(:avis, claimant:, dossier: dossier_termine, experts_procedure: another_experts_procedure, answer: 'yop') }

        before do
          another_experts_procedure
          dossier_termine
          another_avis_without_answer
          another_avis_with_answer
          get :index
        end

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:avis_by_procedure).keys).to match_array([procedure, another_procedure])
        end
      end
    end

    describe '#procedure' do
      context 'without filter' do
        let!(:oldest_avis_without_answer) { create(:avis, dossier: dossier, claimant: claimant, experts_procedure: experts_procedure, created_at: 2.years.ago) }
        before { get :procedure, params: { procedure_id: procedure_to_show.id } }

        context 'with legitimates avis' do
          let(:procedure_to_show) { procedure }

          it do
            expect(response).to have_http_status(:success)
            expect(assigns(:avis_a_donner)).to match_array([avis_without_answer, oldest_avis_without_answer])
            expect(assigns(:avis_donnes)).to match_array([avis_with_answer])
            expect(assigns(:statut)).to eq('a-donner')
          end
        end

        context 'with a revoked avis' do
          let(:procedure_to_show) { revoked_procedure }

          it { expect(response).to redirect_to expert_all_avis_path }
        end
      end

      context 'with a statut equal to donnes' do
        before { get :procedure, params: { statut: 'donnes', procedure_id: } }

        it { expect(assigns(:statut)).to eq('donnes') }
      end

      context 'with different procedure' do
        subject { get :procedure, params: { statut: 'donnes', procedure_id: } }

        it 'fails' do
          sign_in(create(:expert).user)
          subject
          expect(response).to redirect_to(expert_all_avis_path)
          expect(flash.alert).to eq("Vous n’avez pas accès à cette démarche.")
        end
      end
    end

    describe '#bilans_bdf' do
      let(:avis) { avis_without_answer }

      before { get :bilans_bdf, params: { id: avis, procedure_id: } }

      it { expect(response).to redirect_to(expert_avis_path(avis_without_answer)) }

      context 'with a revoked avis' do
        let(:avis) { revoked_avis }

        it { expect(response).to redirect_to(root_path) }
      end
    end

    describe '#telecharger_pjs' do
      let(:avis) { avis_with_answer }
      subject { get :telecharger_pjs, params: { id: avis.id, procedure_id: } }

      context 'with a valid avis' do
        it do
          service = instance_double(PiecesJustificativesService)
          expect(PiecesJustificativesService).to receive(:new).with(user_profile: expert, export_template: nil).and_return(service)
          expect(service).to receive(:generate_dossiers_export).with(Dossier.where(id: dossier)).and_return([])
          expect(service).to receive(:liste_documents).with(Dossier.where(id: dossier)).and_return([])
          is_expected.to have_http_status(:success)
        end
      end

      context 'with a revoked avis' do
        let(:avis) { revoked_avis }

        it { is_expected.to redirect_to(root_path) }
      end

      context 'with a another avis' do
        let(:avis) { create(:avis) }

        it { is_expected.to redirect_to(expert_all_avis_path) }
      end
    end

    describe '#show' do
      subject { get :show, params: { id: avis_with_answer.id, procedure_id: } }

      context 'with a valid avis' do
        before { subject }

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:avis)).to eq(avis_with_answer)
          expect(assigns(:dossier)).to eq(dossier)
        end
      end

      context 'with a revoked avis' do
        it "refuse l’accès au dossier" do
          avis_with_answer.update!(revoked_at: Time.zone.now)
          subject
          expect(flash.alert).to eq("Vous n’avez plus accès à ce dossier.")
          expect(response).to redirect_to(root_path)
        end
      end

      context 'with an avis that does not belongs to current_expert' do
        it "refuse l’accès au dossier" do
          sign_in(create(:expert).user)
          subject
          expect(response).to redirect_to(expert_all_avis_path)
          expect(flash.alert).to eq("Vous n’avez pas accès à cet avis.")
        end
      end
    end

    describe '#instruction' do
      subject { get :instruction, params: { id: avis_to_instruct.id, procedure_id: } }

      context 'with valid avis' do
        let(:avis_to_instruct) { avis_without_answer }
        before { subject }

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:avis)).to eq(avis_without_answer)
          expect(assigns(:dossier)).to eq(dossier)
        end
      end

      context 'with an avis that does not belongs to current_expert' do
        let(:avis_to_instruct) { avis_without_answer }

        it "refuse l’accès au dossier" do
          sign_in(create(:expert).user)
          subject
          expect(response).to redirect_to(expert_all_avis_path)
          expect(flash.alert).to eq("Vous n’avez pas accès à cet avis.")
        end
      end

      context 'with a revoked avis' do
        let(:avis_to_instruct) { revoked_avis }
        before { subject }

        it { expect(response).to redirect_to root_path }
      end
    end

    context 'with destroyed claimant' do
      render_views
      it 'does not raise' do
        avis_with_merged_instructeur = create(:avis, dossier: dossier, claimant: another_instructeur, experts_procedure: experts_procedure)
        another_instructeur.user.destroy
        sign_in(expert.user)
        get :instruction, params: { id: avis_with_merged_instructeur.id, procedure_id: }
        expect(response).to have_http_status(200)
      end
    end

    describe '#messagerie' do
      let(:avis) { avis_without_answer }
      subject { get :messagerie, params: { id: avis.id, procedure_id: } }

      context 'with valid avis' do
        before { subject }

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:avis)).to eq(avis_without_answer)
          expect(assigns(:dossier)).to eq(dossier)
        end
      end

      context 'with an avis that does not belongs to current_expert' do
        it "refuse l’accès au dossier" do
          sign_in(create(:expert).user)
          subject
          expect(response).to redirect_to(expert_all_avis_path)
          expect(flash.alert).to eq("Vous n’avez pas accès à cet avis.")
        end
      end

      context 'with a revoked avis' do
        let(:avis) { revoked_avis }

        it { is_expected.to redirect_to(root_path) }
      end
    end

    describe '#update' do
      before { travel_to(now) }

      let(:avis) { avis_without_answer }

      subject do
        post :update, params: { id: avis.id, procedure_id:, avis: { answer: 'answer' } }
        avis.reload
      end

      context 'on a revoked avis' do
        let(:avis) { revoked_avis }

        it { expect(subject).to redirect_to(root_path) }
      end

      context 'without attachment' do
        it 'should be ok' do
          expect(subject).to redirect_to(instruction_expert_avis_path(avis.procedure, avis))
          expect(avis.answer).to eq('answer')
          expect(avis.piece_justificative_file).to_not be_attached
          expect(dossier.reload.last_avis_updated_at).to eq(now)
          expect(flash.notice).to eq('Votre réponse est enregistrée.')
        end
      end

      context 'when an instructeur wants to be notified by email' do
        let!(:ip) { create(:instructeurs_procedure, instructeur: instructeur_with_instant_avis_notification, procedure:, instant_email_new_expert_avis: true) }

        before do
          instructeur_with_instant_avis_notification.follow(avis_without_answer.dossier)
          instructeur_without_instant_avis_notification.follow(avis_without_answer.dossier)
        end

        it 'The instructeur should be notified of the new avis' do
          expect(DossierMailer).to receive(:notify_new_avis_to_instructeur).once.with(avis_without_answer, instructeur_with_instant_avis_notification.email).and_return(double(deliver_later: true))
          subject
        end
      end

      context 'with attachment' do
        let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

        before do
          expect(ClamavService).to receive(:safe_file?).and_return(true)
          post :update, params: { id: avis_without_answer.id, procedure_id:, avis: { answer: 'answer', piece_justificative_file: file } }
          perform_enqueued_jobs
          avis_without_answer.reload
        end

        it 'should be ok' do
          expect(response).to redirect_to(instruction_expert_avis_path(avis_without_answer.procedure, avis_without_answer))
          expect(avis_without_answer.answer).to eq('answer')
          expect(avis_without_answer.piece_justificative_file).to be_attached
          expect(flash.notice).to eq('Votre réponse est enregistrée.')
        end
      end

      context 'with an avis that does not belongs to current_expert' do
        before { sign_in(create(:expert).user) }

        it "refuse l’accès au dossier" do
          expect(subject).to redirect_to(expert_all_avis_path)
          expect(flash.alert).to eq("Vous n’avez pas accès à cet avis.")
        end
      end

      context "when dossier had attente_avis notification" do
        let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis) }

        it "destroy notification for all instructeurs" do
          subject
          expect(DossierNotification.exists?(notification.id)).to be_falsey
        end
      end

      context "when there are instructeurs wish to be notified" do
        let!(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur, another_instructeur]) }

        before do
          dossier.assign_to_groupe_instructeur(groupe_instructeur, DossierAssignment.modes.fetch(:auto))
          instructeur.followed_dossiers << dossier
        end

        it "create avis_externe notification" do
          expect { subject }.to change(DossierNotification, :count).by(1)

          notification = DossierNotification.last
          expect(notification.dossier_id).to eq(dossier.id)
          expect(notification.instructeur_id).to eq(instructeur.id)
          expect(notification.notification_type).to eq("avis_externe")
        end
      end
    end

    describe '#create_commentaire' do
      let(:file) { nil }
      let(:scan_result) { true }
      let(:now) { Time.zone.parse("14/07/1789") }
      let(:avis) { avis_without_answer }

      subject { post :create_commentaire, params: { id: avis.id, procedure_id:, commentaire: { body: 'commentaire body', piece_jointe: [file] } } }

      before do
        allow(ClamavService).to receive(:safe_file?).and_return(scan_result)
        travel_to(now)
      end

      it do
        subject

        expect(response).to redirect_to(messagerie_expert_avis_path(avis_without_answer.procedure, avis_without_answer))
        expect(dossier.commentaires.map(&:body)).to match(['commentaire body'])
        expect(dossier.reload.last_commentaire_updated_at).to eq(now)
      end

      context "with a file" do
        let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

        it do
          expect { subject }.to change(Commentaire, :count).by(1)
          expect(Commentaire.last.piece_jointe.first.filename).to eq("piece_justificative_0.pdf")
        end
      end

      context 'with a revoked avis' do
        let(:avis) { revoked_avis }

        it { is_expected.to redirect_to(root_path) }
      end

      context "when there are instructeurs followers" do
        before do
          instructeur.followed_dossiers << dossier
          subject
        end

        it "create message notification for instructeurs follower" do
          expect(DossierNotification.count).to eq(1)

          notification = DossierNotification.last
          expect(notification.dossier_id).to eq(dossier.id)
          expect(notification.instructeur_id).to eq(instructeur.id)
          expect(notification.notification_type).to eq("message")
        end
      end
    end

    describe '#avis_new' do
      before do
        allow(Expert).to receive(:autocomplete_mails).and_return([])
        get :avis_new, params: { procedure_id: procedure.id, id: avis_without_answer.id }
      end

      it { expect(Expert).to have_received(:autocomplete_mails).with(procedure) }
    end

    describe '#create_avis' do
      let(:previous_avis_confidentiel) { false }
      let(:previous_revoked_at) { nil }
      let!(:previous_avis) { create(:avis, dossier:, claimant:, experts_procedure:, confidentiel: previous_avis_confidentiel, revoked_at: previous_revoked_at) }
      let(:emails) { ["a@b.com"] }
      let(:introduction) { 'introduction' }
      let(:created_avis) { Avis.last }
      let!(:old_avis_count) { Avis.count }
      let(:invite_linked_dossiers) { nil }
      let(:introduction_file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
      let(:confidentiel) { false }
      let(:question_label) { '' }

      before do
        travel_to(now)
        post :create_avis, params: { id: previous_avis.id, procedure_id:, avis: { emails:, introduction:, experts_procedure:, confidentiel:, invite_linked_dossiers:, introduction_file:, question_label: } }
        created_avis.reload
      end

      context 'from a revoked avis' do
        let(:previous_revoked_at) { Time.zone.now }

        it do
          expect(response).to redirect_to(root_path)
          expect(Avis.last).to eq(previous_avis)
        end
      end

      context 'when an invalid email' do
        let(:emails) { ["toto.fr"] }

        it do
          expect(response).to render_template :instruction
          expect(flash.alert).to eq("toto.fr : Le champ « Email » est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com")
          expect(Avis.last).to eq(previous_avis)
          expect(dossier.last_avis_updated_at).to eq(nil)
        end
      end

      context 'with a question' do
        let(:question_label) { "question" }

        it do
          expect(created_avis.question_label).to eq('question')
          expect(response).to redirect_to(instruction_expert_avis_path(previous_avis.procedure, previous_avis))
        end
      end

      context 'ask review with attachment' do
        let(:emails) { ["toto@totomail.com"] }

        it do
          expect(created_avis.introduction_file).to be_attached
          expect(created_avis.introduction_file.filename).to eq("piece_justificative_0.pdf")
          expect(created_avis.dossier.reload.last_avis_updated_at).to eq(now)
          expect(flash.notice).to eq("Une demande d’avis a été envoyée à toto@totomail.com")
        end
      end

      context 'with multiple emails' do
        let(:emails) { ["toto.fr", "titi@titimail.com"] }

        it do
          expect(response).to render_template :instruction
          expect(flash.alert).to eq("toto.fr : Le champ « Email » est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com")
          expect(flash.notice).to eq("Une demande d’avis a été envoyée à titi@titimail.com")
          expect(Avis.count).to eq(old_avis_count + 1)
        end
      end

      context 'when the previous avis is public' do
        context 'when the user asked for a public avis' do
          it do
            expect(created_avis.confidentiel).to be(false)
            expect(created_avis.introduction).to eq(introduction)
            expect(created_avis.dossier).to eq(previous_avis.dossier)
            expect(created_avis.claimant).to eq(expert)
            expect(response).to redirect_to(instruction_expert_avis_path(previous_avis.procedure, previous_avis))
          end
        end

        context 'when the user asked for a confidentiel avis' do
          let(:confidentiel) { true }

          it { expect(created_avis.confidentiel).to be(true) }
        end
      end

      context 'when the previous avis is confidentiel' do
        let(:previous_avis_confidentiel) { true }

        context 'when the user asked for a public avis' do
          let(:confidentiel) { false }

          it { expect(created_avis.confidentiel).to be(true) }
        end
      end

      context 'with linked dossiers' do
        let(:types_de_champ_public) { [{ type: :dossier_link }] }
        let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

        context 'when the expert doesn’t share linked dossiers' do
          let(:invite_linked_dossiers) { false }

          it 'sends a single avis for the main dossier, but doesn’t give access to the linked dossiers' do
            expect(flash.notice).to eq("Une demande d’avis a été envoyée à a@b.com")
            expect(Avis.count).to eq(old_avis_count + 1)
            expect(created_avis.dossier).to eq(dossier)
          end
        end

        context 'when the expert also shares the linked dossiers' do
          context 'and the expert can access the linked dossiers' do
            let(:created_avis) { create(:avis, dossier: dossier, claimant: claimant, email: "toto3@gmail.com") }
            let(:linked_dossier) { Dossier.find_by(id: dossier.reload.project_champs_public.filter(&:dossier_link?).filter_map(&:value)) }
            let(:linked_avis) { create(:avis, dossier: linked_dossier, claimant: claimant) }
            let(:invite_linked_dossiers) { true }

            it 'sends one avis for the main dossier' do
              expect(flash.notice).to eq("Une demande d’avis a été envoyée à a@b.com")
              expect(created_avis.dossier).to eq(dossier)
            end

            it 'sends another avis for the linked dossiers' do
              expect(Avis.count).to eq(old_avis_count + 2)
              expect(linked_avis.dossier).to eq(linked_dossier)
            end
          end

          context 'but the expert can’t access the linked dossier' do
            it 'sends a single avis for the main dossier, but doesn’t give access to the linked dossiers' do
              expect(flash.notice).to eq("Une demande d’avis a été envoyée à a@b.com")
              expect(Avis.count).to eq(old_avis_count + 1)
              expect(created_avis.dossier).to eq(dossier)
            end
          end
        end
      end

      context 'when creating avis for linked dossiers with different procedures' do
        let(:types_de_champ_public) { [{ type: :dossier_link }] }
        let(:another_procedure) { create(:procedure, :published) }
        let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
        let(:linked_dossier) { create(:dossier, :en_construction, procedure: another_procedure) }
        let(:linked_experts_procedure) { create(:experts_procedure, expert: previous_avis.expert, procedure: another_procedure) }
        let!(:linked_avis) { create(:avis, dossier: linked_dossier, experts_procedure: linked_experts_procedure, claimant: previous_avis.claimant) }

        let(:invite_linked_dossiers) { true }

        before do
          dossier_link_champ = dossier.champs.find_by(type: "Champs::DossierLinkChamp")
          dossier_link_champ.update!(value: linked_dossier.id)
        end

        it 'creates experts_procedure with correct procedure for each dossier' do
          expect {
            post :create_avis, params: {
              id: previous_avis.id,
              procedure_id: procedure.id,
              avis: {
                emails: ["expert@example.com"],
                introduction: "Please review",
                confidentiel: false,
                invite_linked_dossiers: true,
              },
            }
          }.to change(Avis, :count).by(2)

          Avis.all.each do |avis|
            # Verify experts_procedures are created with correct procedures
            expect(avis.experts_procedure.procedure_id).to eq(avis.dossier.procedure.id)
          end
        end
      end
    end
  end

  context 'without an expert signed in' do
    let(:claimant) { create(:instructeur) }
    let(:expert) { create(:expert) }
    let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure) }
    let(:dossier) { create(:dossier) }
    let(:avis) { create(:avis, dossier: dossier, experts_procedure: experts_procedure, claimant: claimant) }
    let(:procedure) { dossier.procedure }
    let(:procedure_id) { procedure.id }

    describe '#sign_up' do
      subject do
        get :sign_up, params: { id: avis.id, procedure_id:, email: avis.expert.email }
      end

      context 'when the avis is revoked' do
        before { avis.update(revoked_at: Time.zone.now) }

        it { is_expected.to redirect_to(root_path) }
      end

      context 'when the expert hasn’t signed up yet' do
        before { expert.user.update(last_sign_in_at: nil) }

        it { is_expected.to have_http_status(:success) }
      end

      context 'when the expert has already signed up' do
        before { expert.user.update(last_sign_in_at: Time.zone.now) }

        context 'and the expert belongs to the invitation' do
          context 'and the expert is authenticated' do
            before { sign_in(expert.user) }

            it { is_expected.to redirect_to expert_avis_url(avis.procedure, avis) }
          end

          context 'and the expert is not authenticated' do
            before { sign_out(expert.user) }

            it { is_expected.to redirect_to new_user_session_url }
          end
        end

        context 'and the expert does not belong to the invitation' do
          let(:avis) { create(:avis, email: 'another_expert@avis.com', dossier: dossier, experts_procedure: experts_procedure) }

          before { sign_in(expert.user) }
          # redirected to dossier but then the instructeur gonna be banished !
          it { is_expected.to redirect_to expert_avis_url(avis.procedure, avis) }
        end
      end
    end

    describe '#update_expert' do
      let(:avis_id) { avis.id }
      let(:email) { avis.expert.email }
      let(:password) { SECURE_PASSWORD }
      let(:valid_confirmation_token) { "1234" }
      before { avis.expert.user.update(confirmation_token: valid_confirmation_token) }

      subject do
          post :update_expert, params: {
            id: avis_id,
            procedure_id:,
            email:,
            user: {
              password:,
              confirmation_token:,
            },
          }
        end

      context 'when token is invalid' do
        let(:confirmation_token) { "kthxbye" }

        it { is_expected.to redirect_to(root_path) }
      end

      context 'when valid token is provided' do
        let(:confirmation_token) { valid_confirmation_token }

        context 'when the avis is revoked' do
          before { avis.update(revoked_at: Time.zone.now) }

          it { is_expected.to redirect_to(root_path) }
        end

        context 'when the expert hasn’t signed up yet' do
          before { expert.user.update(last_sign_in_at: nil) }

          it 'saves the expert new password' do
            subject
            expect(expert.user.reload.valid_password?(SECURE_PASSWORD)).to be true
          end

          it { is_expected.to redirect_to expert_all_avis_path }
        end

        context 'with a random avis, procedure and user' do
          let(:avis_id) { create(:avis).id }
          let(:random_user) { create(:user, password: '{Another-$3cure-p4ssWord}') }
          let(:email) { random_user.email }

          it 'doesn’t change the random user password' do
            expect(random_user.reload.valid_password?(password)).to be false
            subject
            expect(random_user.reload.valid_password?(password)).to be false
            expect(flash[:alert]).to eq("Vous n’avez pas accès à cet avis.")
          end
        end

        context 'with a matching avis procedure, and a random user' do
          let(:avis) { create(:avis) }
          let(:avis_id) { avis.id }
          let(:procedure_id) { avis.procedure.id }
          let(:random_user) { create(:user, password: '{Another-$3cure-p4ssWord}') }
          let(:email) { random_user.email }

          it 'doesn’t change the random user password' do
            expect(random_user.reload.valid_password?(password)).to be false
            subject
            expect(random_user.reload.valid_password?(password)).to be false
            expect(flash[:alert]).to eq("Vous n’avez pas accès à cet avis.")
          end
        end

        context 'when the expert has already signed up' do
          before { expert.user.update(last_sign_in_at: Time.zone.now) }

          it 'doesn’t change the expert password' do
            subject
            expect(expert.user.reload.valid_password?('{Another-$3cure-p4ssWord}')).to be false
          end

          it { is_expected.to redirect_to new_user_session_url }
        end
      end
    end
  end
end
