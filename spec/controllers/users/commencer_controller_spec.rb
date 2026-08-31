# frozen_string_literal: true

describe Users::CommencerController, type: :controller do
  let(:user) { create(:user) }
  let(:published_procedure) { create(:procedure, :for_individual, :published, public_type_de_champs:, robots_indexable:) }
  let(:public_type_de_champs) { [] }
  let(:draft_procedure) { create(:procedure, :with_path) }
  let(:robots_indexable) { true }

  describe '#commencer' do
    subject { get :commencer, params: { path: path } }

    context 'when the path is for a published procedure' do
      let(:path) { published_procedure.path }
      render_views

      it 'renders the view' do
        expect(subject.status).to eq(200)
        expect(subject).to render_template('show')
        expect(assigns(:procedure)).to eq published_procedure
        expect(assigns(:revision)).to eq published_procedure.published_revision
        expect(response.body).to include("index,follow")
      end
    end

    context "when procedure is not indexable" do
      render_views
      let(:robots_indexable) { false }
      let(:path) { published_procedure.path }

      it "apply robots directives" do
        subject
        expect(response.body).to include("noindex,nofollow")
      end
    end

    context 'when there is an old path' do
      let!(:old_path) do
        travel_to(1.day.ago) do
          create(:procedure_path, procedure: published_procedure, path: 'old_path')
        end
      end

      let!(:new_path) { create(:procedure_path, procedure: published_procedure, path: 'new_path') }

      let(:path) { old_path.path }

      it 'redirects to the new path' do
        expect(subject.status).to eq(301)
        expect(subject).to redirect_to(commencer_path(path: new_path.path))
      end
    end

    context 'when the path is for a draft procedure' do
      let(:path) { draft_procedure.path }
      render_views

      it 'renders the view' do
        expect(subject.status).to eq(200)
        expect(subject).to render_template('show')
        expect(assigns(:procedure)).to eq draft_procedure
        expect(assigns(:revision)).to eq draft_procedure.draft_revision
        expect(response.body).to include("noindex,nofollow")
      end
    end

    context 'when the path does not exist' do
      let(:path) { 'hello' }

      it 'redirects with an error message' do
        expect(subject).to redirect_to(not_found_path('hello'))
        expect(flash[:alert]).to eq(I18n.t('errors.messages.procedure_not_found'))
      end
    end

    context 'when procedure without service is closed' do
      it 'works' do
        published_procedure.service = nil
        published_procedure.organisation = "hello"
        published_procedure.close!
        get :commencer, params: { path: published_procedure.path }
        expect(response).to redirect_to(closing_details_path(published_procedure.path))
      end
    end

    context 'when procedure with service is closed' do
      it 'works' do
        published_procedure.service = create(:service)
        published_procedure.close!
        get :commencer, params: { path: published_procedure.path }
        expect(response).to redirect_to(closing_details_path(published_procedure.path))
      end
    end

    context 'when procedure has a replaced_by_procedure' do
      let(:path) { published_procedure.path }

      it 'redirects to new procedure' do
        replaced_by_procedure = create(:procedure, :published)
        published_procedure.update!(replaced_by_procedure_id: replaced_by_procedure.id)
        published_procedure.close!
        expect(subject).to redirect_to(commencer_path(path: replaced_by_procedure.path))
      end
    end

    context 'when procedure has a replaced_by_procedure pointing to itself (circular reference that should not be allowed in a next fix)' do
      let(:path) { published_procedure.path }

      it 'does not create an infinite redirect loop and redirects to closing_details instead' do
        published_procedure.update!(replaced_by_procedure_id: published_procedure.id)
        published_procedure.close!
        expect(subject).to redirect_to(closing_details_path(published_procedure.path))
        expect(subject.status).to eq(302)
      end
    end

    context 'when a dossier has been prefilled by POST before' do
      let(:dossier) { create(:dossier, :brouillon, :prefilled, user: user) }
      let(:path) { dossier.procedure.path }

      subject { get :commencer, params: { path: path, prefill_token: dossier.prefill_token } }

      shared_examples 'a prefilled brouillon dossier retriever' do
        it 'stores the prefill token in session' do
          expect { subject }.to change { controller.stored_location_for(:user) }.to(commencer_path(dossier.procedure.path, prefill_token: dossier.prefill_token))
        end

        context 'when the dossier is a prefilled brouillon and the prefill token is present' do
          it 'retrieves the dossier' do
            subject
            expect(assigns(:prefilled_dossier)).to eq(dossier)
          end
        end

        context 'when the dossier is not prefilled' do
          before do
            dossier.prefilled = false
            dossier.save(validate: false)
          end

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
        end

        context 'when the dossier is not a brouillon' do
          before { dossier.en_construction! }

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
        end

        context 'when the prefill token does not match any dossier' do
          before { dossier.prefill_token = "totoro" }

          it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end

      context 'when the user is unauthenticated' do
        let(:user) { nil }

        it_behaves_like 'a prefilled brouillon dossier retriever'

        context 'when rendered view' do
          render_views
          it 'renders the page' do
            subject
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'when the user is authenticated' do
        context 'when the dossier already has an owner' do
          let(:user) { create(:user) }

          context 'when the user is the dossier owner' do
            before { sign_in user }

            it_behaves_like 'a prefilled brouillon dossier retriever'
          end

          context 'when the user is not the dossier owner' do
            before { sign_in create(:user) }

            it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
          end
        end

        context 'when the dossier does not have an owner yet' do
          let(:user) { nil }
          let(:newly_authenticated_user) { create(:user) }

          before { sign_in newly_authenticated_user }

          it { expect { subject }.to change { dossier.reload.user }.from(nil).to(newly_authenticated_user) }

          it 'sends the notify_new_draft email and enqueues AMI notification' do
            allow(Ami::CreateNotificationService).to receive(:call)
            expect { perform_enqueued_jobs { subject } }.to change { ActionMailer::Base.deliveries.count }.by(1)

            dossier = Dossier.last
            mail = ActionMailer::Base.deliveries.last
            expect(mail.subject).to eq("Retrouvez votre brouillon pour la démarche « #{dossier.procedure.libelle} »")
            expect(mail.html_part.body).to include(dossier_path(dossier))
            expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:)
          end
        end

        context 'when the dossier does not have an owner yet and user is france connected' do
          let(:newly_authenticated_user) { create(:user, :with_fci) }
          let(:dossier) { create(:dossier, :prefilled, user: nil, procedure: published_procedure, individual: build(:individual, nom: 'Prefilled', prenom: 'Jean', gender: 'M.')) }

          before { sign_in newly_authenticated_user }

          it 'overwrites prefilled identity with FranceConnect data' do
            subject
            dossier.reload
            fc_info = newly_authenticated_user.france_connect_informations.first
            expect(dossier.individual.nom).to eq(fc_info.family_name)
            expect(dossier.individual.prenom).to eq(fc_info.given_name)
            expect(dossier.individual.gender).to eq(Individual::GENDER_FEMALE)
          end
        end
      end
    end

    context 'when a dossier is being prefilled by GET' do
      let(:public_type_de_champs) { [{}] }
      let(:type_de_champ_text) { published_procedure.published_revision.type_de_champs.first }
      let(:path) { published_procedure.path }
      let(:user) { create(:user) }

      context "when the dossier does not exists yet" do
        subject { get :commencer, params: { path: path, "champ_#{type_de_champ_text.to_typed_id}" => "blabla", "identite_nom" => "Dupont" } }

        shared_examples 'a prefilled brouillon dossier creator' do
          it 'creates a dossier' do
            expect { subject }.to change { published_procedure.dossiers.count }.by(1)
            dossier = published_procedure.dossiers.last
            expect(session[:prefill_token]).to eq(dossier.prefill_token)
            expect(session[:prefill_params_digest]).to eq(PrefillChamps.digest({ "champ_#{type_de_champ_text.to_typed_id}" => "blabla" }))
            expect(dossier.champ_data.where(stable_id: type_de_champ_text.stable_id).first.value).to eq("blabla")
            expect(dossier.individual.nom).to eq("Dupont")
          end
        end

        context 'when the user is unauthenticated' do
          it_behaves_like 'a prefilled brouillon dossier creator'
        end

        context 'when the user is authenticated' do
          before { sign_in user }

          it_behaves_like 'a prefilled brouillon dossier creator'

          it { expect { subject }.to change { published_procedure.dossiers.last&.user }.from(nil).to(user) }

          it 'sends the notify_new_draft email and enqueues AMI notification' do
            allow(Ami::CreateNotificationService).to receive(:call)
            expect { perform_enqueued_jobs { subject } }.to change { ActionMailer::Base.deliveries.count }.by(1)

            dossier = Dossier.last
            mail = ActionMailer::Base.deliveries.last
            expect(mail.subject).to eq("Retrouvez votre brouillon pour la démarche « #{dossier.procedure.libelle} »")
            expect(mail.html_part.body).to include(dossier_path(dossier))
            expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:)
          end
        end
      end

      context "when prefilled params are passed" do
        subject { get :commencer, params: { path: path, prefill_token: "token", "champ_#{type_de_champ_text.to_typed_id}" => "blabla" } }

        context "when the associated dossier exists" do
          let(:procedure) { create(:procedure, public_type_de_champs: [{}]) }
          let!(:dossier) { create(:dossier, :prefilled, procedure:, prefill_token: "token") }

          it "does not create a new dossier" do
            expect { subject }.not_to change(Dossier, :count)
            expect(assigns(:prefilled_dossier)).to eq(dossier)
          end
        end
        context "when the associated dossier does not exists" do
          it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end

      context "when session params exists" do
        subject { get :commencer, params: { path: path, "champ_#{type_de_champ_text.to_typed_id}" => "blabla" } }

        before do
          session[:prefill_token] = "token"
          session[:prefill_params_digest] = PrefillChamps.digest({ "champ_#{type_de_champ_text.to_typed_id}" => "blabla" })
        end

        context "when the associated dossier exists" do
          let!(:dossier) { create(:dossier, :prefilled, prefill_token: "token") }

          it "does not create a new dossier" do
            expect { subject }.not_to change(Dossier, :count)
            expect(assigns(:prefilled_dossier)).to eq(dossier)
          end
        end

        context "when the associated dossier does not exists" do
          it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end
    end
  end

  shared_examples 'a prefill token storage' do
    it 'stores the prefill token' do
      subject
      expect(controller.stored_location_for(:user)).to include('prefill_token')
    end
  end

  describe '#sign_in' do
    context 'for a published procedure' do
      subject { get :sign_in, params: { path: published_procedure.path } }

      it 'set the path to return after sign-in to the procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: published_procedure.path))
      end

      it { expect(subject).to redirect_to(new_user_session_path) }

      context 'when a prefill token is given' do
        subject { get :sign_in, params: { path: published_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end

    context 'for a draft procedure' do
      subject { get :sign_in, params: { path: draft_procedure.path } }

      it 'set the path to return after sign-in to the draft procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: draft_procedure.path))
      end

      it { expect(subject).to redirect_to(new_user_session_path) }

      context 'when a prefill token is given' do
        subject { get :sign_in, params: { path: draft_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end

    context 'when the path doesn’t exist' do
      subject { get :sign_in, params: { path: 'hello' } }

      it 'redirects with an error message' do
        expect(subject).to redirect_to(not_found_path('hello'))
        expect(flash[:alert]).to eq(I18n.t('errors.messages.procedure_not_found'))
      end
    end
  end

  describe '#sign_up' do
    context 'for a published procedure' do
      subject { get :sign_up, params: { path: published_procedure.path } }

      it 'set the path to return after sign-up to the procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: published_procedure.path))
      end

      it { expect(subject).to redirect_to(new_user_registration_path) }

      context 'when a prefill token is given' do
        subject { get :sign_up, params: { path: published_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end

    context 'for a draft procedure' do
      subject { get :sign_up, params: { path: draft_procedure.path } }

      it 'set the path to return after sign-up to the draft procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: draft_procedure.path))
      end

      it { expect(subject).to redirect_to(new_user_registration_path) }

      context 'when a prefill token is given' do
        subject { get :sign_up, params: { path: draft_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end

    context 'when the path doesn’t exist' do
      subject { get :sign_up, params: { path: 'hello' } }

      it 'redirects with an error message' do
        expect(subject).to redirect_to(not_found_path('hello'))
        expect(flash[:alert]).to eq(I18n.t('errors.messages.procedure_not_found'))
      end
    end
  end

  describe '#france_connect' do
    context 'for a published procedure' do
      subject { get :france_connect, params: { path: published_procedure.path } }

      it 'set the path to return after sign-up to the procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: published_procedure.path))
      end

      it { expect(subject).to redirect_to(france_connect_path) }

      context 'when a prefill token is given' do
        subject { get :france_connect, params: { path: published_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end

    context 'for a draft procedure' do
      subject { get :france_connect, params: { path: draft_procedure.path } }

      it 'set the path to return after sign-up to the draft procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: draft_procedure.path))
      end

      it { expect(subject).to redirect_to(france_connect_path) }

      context 'when a prefill token is given' do
        subject { get :france_connect, params: { path: draft_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end

    context 'when the path doesn’t exist' do
      subject { get :france_connect, params: { path: 'hello' } }

      it 'redirects with an error message' do
        expect(subject).to redirect_to(not_found_path('hello'))
        expect(flash[:alert]).to eq(I18n.t('errors.messages.procedure_not_found'))
      end
    end
  end

  describe '#pro_connect' do
    context 'for a published procedure' do
      subject { get :pro_connect, params: { path: published_procedure.path } }

      it 'set the path to return after sign-up to the procedure start page' do
        subject
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: published_procedure.path))
        expect(subject).to redirect_to(pro_connect_path)
      end

      context 'when a prefill token is given' do
        subject { get :pro_connect, params: { path: published_procedure.path, prefill_token: 'prefill_token' } }

        it_behaves_like 'a prefill token storage'
      end
    end
  end

  describe '#dossier_vide_pdf' do
    let(:procedure) { procedures.individual }
    before { get :dossier_vide_pdf, params: { path: procedure.path } }

    context 'published procedure' do
      it 'works' do
        expect(response).to have_http_status(:success)
      end
    end

    context 'not yet published procedure' do
      let(:procedure) { create(:procedure, :with_service, :with_path) }

      it 'redirects to procedure not found' do
        expect(response).to have_http_status(302)
        expect(subject).to redirect_to(not_found_path(procedure.path))
      end
    end

    context 'closed procedure' do
      it 'works' do
        procedure.service = create(:service)
        procedure.close!
        expect(response).to have_http_status(:success)
      end
    end

    context 'with the :dossier_vide_typst flag enabled' do
      render_views
      let(:procedure) { create(:procedure, :published, :with_service, :with_path, libelle: 'Ma démarche') }

      before do
        Flipper.enable(:dossier_vide_typst, procedure)
        allow(TypstService).to receive(:generate_pdf).and_return('%PDF-fake')
        allow(WeasyprintService).to receive(:generate_pdf)
        get :dossier_vide_pdf, params: { path: procedure.path }
      end

      it 'generates the PDF via Typst' do
        expect(TypstService).to have_received(:generate_pdf)
          .with('dossier_vide', anything)
        expect(WeasyprintService).not_to have_received(:generate_pdf)
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('%PDF-fake')
      end

      it 'titles the document with the procedure libelle (PDF/UA metadata)' do
        expect(TypstService).to have_received(:generate_pdf)
          .with(anything, hash_including(title: 'Ma démarche'))
      end
    end

    context 'with the :dossier_vide_weasyprint flag enabled alone' do
      render_views
      let(:procedure) { create(:procedure, :published, :with_service, :with_path, libelle: 'Ma démarche') }

      before do
        Flipper.enable(:dossier_vide_weasyprint, procedure)
        allow(TypstService).to receive(:generate_pdf)
        allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-fake')
        get :dossier_vide_pdf, params: { path: procedure.path }
      end

      it 'generates the PDF via WeasyPrint, titled with the procedure libelle' do
        expect(WeasyprintService).to have_received(:generate_pdf)
          .with(a_string_matching(%r{<title>Ma démarche</title>}), hash_including(procedure_id: procedure.id))
        expect(TypstService).not_to have_received(:generate_pdf)
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('%PDF-fake')
      end
    end

    context 'with the :dossier_vide_typst flag enabled but Typst failing' do
      render_views
      let(:procedure) { create(:procedure, :published, :with_service, :with_path) }

      before do
        Flipper.enable(:dossier_vide_typst, procedure)
        allow(Sentry).to receive(:capture_exception)
        allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error, 'compiler down')
        allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
      end

      it 'falls back to the WeasyPrint rendering when its flag is enabled, and reports the failure' do
        Flipper.enable(:dossier_vide_weasyprint, procedure)

        get :dossier_vide_pdf, params: { path: procedure.path }

        expect(response.body).to eq('%PDF-weasyprint')
        expect(Sentry).to have_received(:capture_exception)
          .with(an_instance_of(TypstService::Error), extra: { procedure_id: procedure.id })
      end

      it 'falls back to the Prawn rendering otherwise' do
        get :dossier_vide_pdf, params: { path: procedure.path }

        expect(response).to have_http_status(:success)
        expect(response.body).to start_with('%PDF-')
        expect(WeasyprintService).not_to have_received(:generate_pdf)
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), anything)
      end

      it 'falls back to the Prawn rendering when WeasyPrint fails in turn' do
        Flipper.enable(:dossier_vide_weasyprint, procedure)
        allow(WeasyprintService).to receive(:generate_pdf).and_raise(WeasyprintService::Error, 'service down')

        get :dossier_vide_pdf, params: { path: procedure.path }

        expect(response).to have_http_status(:success)
        expect(response.body).to start_with('%PDF-')
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), anything)
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(WeasyprintService::Error), anything)
      end
    end

    context 'with the :dossier_vide_typst flag enabled but the PDF rendering raising unexpectedly' do
      let(:procedure) { create(:procedure, :published, :with_service, :with_path) }

      before do
        Flipper.enable(:dossier_vide_typst, procedure)
        allow(Sentry).to receive(:capture_exception)
        allow(TypstService).to receive(:generate_pdf).and_raise(StandardError, 'boom')
        get :dossier_vide_pdf, params: { path: procedure.path }
      end

      it 'falls back to the Prawn rendering and reports to Sentry' do
        expect(response).to have_http_status(:success)
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end

  describe '#dossier_vide_test_pdf' do
    render_views
    before { get :dossier_vide_pdf_test, params: { path: procedure.path }, format: :pdf }

    context 'not published procedure with service' do
      let(:procedure) { create(:procedure, :with_service, :with_path) }

      it 'works' do
        expect(response).to have_http_status(:success)
      end
    end

    context 'not published procedure without service' do
      let(:procedure) { create(:procedure, :with_path, service: nil, organisation: nil) }

      it 'works' do
        expect(response).to have_http_status(:success)
      end
    end
  end

  # Kept out of '#dossier_vide_pdf' on purpose: that group downloads the PDF in a
  # `before` hook, which would count as an extra Typst call here.
  describe '#dossier_vide_pdf caching' do
    render_views

    let(:procedure) { create(:procedure, :published, :with_service, :with_path) }

    before do
      Flipper.enable(:dossier_vide_typst, procedure)
      allow(TypstService).to receive(:generate_pdf).and_return('%PDF-fake')
    end

    def download = get(:dossier_vide_pdf, params: { path: procedure.path })

    it 'generates and stores the PDF on the first download' do
      download

      expect(TypstService).to have_received(:generate_pdf).once
      expect(procedure.reload.dossier_vide_pdf).to be_attached
      expect(response.body).to eq('%PDF-fake')
    end

    it 'serves the stored PDF on the next download, without rendering it again' do
      download
      allow(Typst::DossierVidePayload).to receive(:new).and_call_original

      download

      expect(TypstService).to have_received(:generate_pdf).once
      expect(Typst::DossierVidePayload).not_to have_received(:new)
      expect(response.body).to eq('%PDF-fake')
    end

    it 'regenerates once the cached PDF has expired' do
      download
      procedure.reload.dossier_vide_pdf.blob.update_column(:created_at, 8.days.ago)
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'regenerates when the presentation changes' do
      download
      procedure.update!(description: 'Une nouvelle présentation')
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'regenerates when the service changes' do
      download
      procedure.service.update!(adresse: '2 rue de la Paix, 75002 Paris')
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'regenerates when a new revision is published' do
      download
      procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'Un champ de plus')
      procedure.publish_revision!(procedure.administrateurs.first)
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'does not cache anything when Typst fails' do
      allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error)

      download

      expect(response).to have_http_status(:success)
      expect(procedure.reload.dossier_vide_pdf).not_to be_attached
    end

    it 'keys the cache by renderer: a PDF cached by one is never served for the other' do
      allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
      download

      Flipper.disable(:dossier_vide_typst, procedure)
      Flipper.enable(:dossier_vide_weasyprint, procedure)
      download

      expect(WeasyprintService).to have_received(:generate_pdf).once
      expect(response.body).to eq('%PDF-weasyprint')
    end

    it 'still serves the rendered PDF when caching it fails' do
      allow(Sentry).to receive(:capture_exception)
      allow_any_instance_of(Procedure).to receive(:store_dossier_vide_pdf).and_raise(StandardError, 'storage down')

      download

      expect(response.body).to eq('%PDF-fake')
      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(StandardError), anything)
      expect(procedure.reload.dossier_vide_pdf).not_to be_attached
    end
  end

  describe '#dossier_vide_pdf_test caching' do
    render_views

    let(:procedure) { create(:procedure, :with_service, :with_path) }

    before do
      Flipper.enable(:dossier_vide_typst, procedure)
      allow(TypstService).to receive(:generate_pdf).and_return('%PDF-fake')
      get :dossier_vide_pdf_test, params: { path: procedure.path }
      get :dossier_vide_pdf_test, params: { path: procedure.path }
    end

    it 'never caches the draft PDF: it is content being edited' do
      expect(TypstService).to have_received(:generate_pdf).twice
      expect(procedure.reload.dossier_vide_pdf).not_to be_attached
    end
  end

  describe '#commencer for moral procedure with pro_connect_for_moral_procedure flag' do
    render_views
    subject { get :commencer, params: { path: procedure.path } }

    before { allow(ProConnectService).to receive(:enabled?).and_return(true) }

    context 'when procedure is moral and flag is enabled' do
      let(:procedure) { procedures.entreprise }

      it 'shows both FranceConnect and ProConnect' do
        subject
        assert_response :success
        expect(response.body).to include('FranceConnect')
        expect(response.body).to include('ProConnect')
      end
    end

    context 'when procedure is moral but flag is disabled (legacy procedure)' do
      let(:procedure) { procedures.entreprise }

      before { procedure.update_column(:pro_connect_for_moral_procedure, false) }

      it 'shows FranceConnect but not ProConnect' do
        subject
        assert_response :success
        expect(response.body).to include('FranceConnect')
        expect(response.body).not_to include('ProConnect')
      end
    end

    context 'when procedure is for individuals' do
      let(:procedure) { create(:procedure, :for_individual, :published) }

      it 'shows FranceConnect but not ProConnect' do
        subject
        assert_response :success
        expect(response.body).to include('FranceConnect')
        expect(response.body).not_to include('ProConnect')
      end
    end
  end

  describe '#commencer with pro_connect_restriction' do
    render_views
    let(:procedure) { create(:procedure, :for_individual, :published, pro_connect_restriction: :all) }

    context 'when procedure has pro_connect restriction and user is not signed in' do
      subject { get :commencer, params: { path: procedure.path } }

      it 'shows only ProConnect button for anonymous user' do
        subject
        assert_response :success
        expect(controller.stored_location_for(:user)).to eq(commencer_path(path: procedure.path))
        expect(response.body).to include("S’identifier avec ProConnect")
        expect(response.body).to include("Seuls les agents disposant d’un compte ProConnect peuvent y accéder")
        expect(response.body).not_to include('france_connect')
      end
    end

    context 'when user is signed in with ProConnect' do
      let(:user) { create(:user) }

      before do
        sign_in user
        cookies.encrypted[:pro_connect_session_info] = { user_id: user.id }.to_json
      end

      subject { get :commencer, params: { path: procedure.path } }

      it 'does not show warning alert' do
        subject
        assert_response :success
        expect(response.body).to include("Commencer")
        expect(response.body).not_to include("S’identifier avec ProConnect")
        expect(response.body).not_to include("Seuls les agents disposant d’un compte ProConnect peuvent y accéder")
      end
    end

    context 'when user is signed in without ProConnect' do
      let(:user) { create(:user) }

      before { sign_in user }

      subject { get :commencer, params: { path: procedure.path } }

      it 'shows warning alert' do
        subject
        assert_response :success
        expect(response.body).not_to include("Commencer")
        expect(response.body).to include("Seuls les agents disposant d’un compte ProConnect peuvent y accéder")
      end
    end
  end
end
