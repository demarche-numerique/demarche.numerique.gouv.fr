# frozen_string_literal: true

describe Instructeurs::ProceduresController, type: :controller do
  describe "before_action: ensure_ownership!" do
    it "is present" do
      before_actions = Instructeurs::ProceduresController
        ._process_action_callbacks
        .filter { |process_action_callbacks| process_action_callbacks.kind == :before }
        .map(&:filter)

      expect(before_actions).to include(:ensure_ownership!)
    end
  end

  describe "ensure_ownership!" do
    let(:instructeur) { create(:instructeur) }

    before do
      @controller.params = @controller.params.merge(procedure_id: asked_procedure.id)
      expect(@controller).to receive(:current_instructeur).and_return(instructeur)
      allow(@controller).to receive(:redirect_to)

      @controller.send(:ensure_ownership!)
    end

    context "when a instructeur asks for its procedure" do
      let(:asked_procedure) { create(:procedure, instructeurs: [instructeur]) }

      it "does not redirects nor flash" do
        expect(@controller).not_to have_received(:redirect_to)
        expect(flash.alert).to eq(nil)
      end
    end

    context "when a instructeur asks for another procedure" do
      let(:asked_procedure) { create(:procedure) }

      it "redirects and flash" do
        expect(@controller).to have_received(:redirect_to).with(root_path)
        expect(flash.alert).to eq("Vous n’avez pas accès à cette démarche")
      end
    end
  end

  describe "#index" do
    let(:instructeur) { create(:instructeur) }
    subject { get :index }

    describe 'tabs explanation' do
      render_views

      before do
        sign_in(instructeur.user)
        subject
      end

      it 'contains tabs explanation' do
        expect(response.body).to have_text('L’onglet « en cours » regroupe')
        expect(response.body).to have_text('L’onglet « en test » regroupe')
        expect(response.body).to have_text('L’onglet « terminée » regroupe')
        expect(response.body).not_to have_text('L’onglet « expirants » contient')
      end
    end

    context "when not logged" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      before { sign_in(instructeur.user) }

      it { expect(response).to have_http_status(:ok) }

      context "with procedures assigned" do
        let(:procedure_draft) { create(:procedure) }
        let(:procedure_published) { create(:procedure, :published) }
        let(:procedure_closed) { create(:procedure, :closed) }
        let(:procedure_draft_discarded) { create(:procedure, :discarded) }
        let(:procedure_closed_discarded) { create(:procedure, :discarded) }
        let(:procedure_not_assigned) { create(:procedure) }

        before do
          [procedure_draft, procedure_published, procedure_closed, procedure_draft_discarded, procedure_closed_discarded].each do |p|
            instructeur.groupe_instructeurs << p.defaut_groupe_instructeur
          end
          subject
        end

        it 'assigns procedures visible to the instructeur' do
          expect(assigns(:all_procedures)).to match_array([procedure_draft, procedure_published, procedure_closed])
          expect(assigns(:procedures)).to match_array([procedure_published])
        end
      end
    end
  end

  describe "#counters" do
    let(:instructeur) { create(:instructeur) }
    subject { get :counters, format: :turbo_stream }

    context "when not logged in" do
      before { subject }
      it { expect(response).to redirect_to(new_user_session_path) }
    end

    context "when logged in" do
      before { sign_in(instructeur.user) }

      it { expect(response).to have_http_status(:ok) }

      context "with procedures and dossiers" do
        let(:procedure_published) { create(:procedure, :published) }
        let(:procedure_with_dossier) { create(:procedure, :published) }
        let(:procedure_draft) { create(:procedure) }
        let(:dossier_en_cours) do
          create(:dossier, :en_construction,
                 procedure: procedure_with_dossier,
                 groupe_instructeur: procedure_with_dossier.defaut_groupe_instructeur)
        end

        before do
          [procedure_published, procedure_with_dossier, procedure_draft].each_with_index do |procedure, idx|
            instructeur.groupe_instructeurs << procedure.defaut_groupe_instructeur

            # #counters expects #index have been run before, which create instructeurs_procedure
            create(:instructeurs_procedure, instructeur:, procedure:, position: idx + 1)
          end

          create(:dossier_notification, dossier: dossier_en_cours, instructeur:, notification_type: "dossier_modifie")
        end

        it 'assigns counters, notifications, default statut' do
          subject

          expect(assigns(:procedures)).to match_array([procedure_published, procedure_with_dossier])
          expect(assigns(:counters).groupes_instructeurs_ids).to match_array(instructeur.groupe_instructeurs.ids)

          expect(assigns(:procedure_ids_with_notifications)).to eq({ a_suivre: [procedure_with_dossier.id], suivis: [], traites: [] })
          expect(assigns(:notifications_counts_per_procedure)).to eq({ procedure_with_dossier.id => { "dossier_modifie" => 1 } })

          expect(assigns(:statut)).to eq('en-cours')
        end
      end

      context "with specific statut parameter" do
        subject { get :counters, params: { statut: 'brouillons' }, format: :turbo_stream }

        let(:procedure_draft) { create(:procedure) }
        let(:procedure_published) { create(:procedure, :published) }

        before do
          instructeur.groupe_instructeurs << procedure_draft.defaut_groupe_instructeur
          instructeur.groupe_instructeurs << procedure_published.defaut_groupe_instructeur
        end

        it 'uses the provided statut' do
          subject

          expect(assigns(:statut)).to eq('brouillons')

          expect(assigns(:procedures)).to match_array([procedure_draft])
        end
      end
    end
  end

  describe "#show" do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :expirable, instructeurs: [instructeur]) }
    let!(:gi_2) { create(:groupe_instructeur, label: '2', procedure: procedure) }
    let!(:gi_3) { create(:groupe_instructeur, label: '3', procedure: procedure) }

    let(:statut) { 'a-suivre' }

    subject do
      get :show, params: { procedure_id: procedure.id, statut: statut }
    end

    describe 'tabs explanation' do
      render_views

      before do
        sign_in(instructeur.user)
        subject
      end

      it 'contains tabs explanation' do
        expect(response.body).to have_text('L’onglet « à suivre » contient')
        expect(response.body).to have_text('L’onglet « suivis par moi » contient')
        expect(response.body).to have_text('L’onglet « traités » contient')
        expect(response.body).to have_text('L’onglet « au total » contient')
        expect(response.body).to have_text('L’onglet « corbeille » contient')
        expect(response.body).to have_text('L’onglet « à archiver » contient')
        expect(response.body).to have_text('L’onglet « expirants » contient')
        expect(response.body).not_to have_text('L’onglet « terminée » regroupe')
      end
    end

    describe 'access to groupes_instructeur' do
      render_views
      let(:procedure) { create(:procedure, instructeurs_self_management_enabled:, instructeurs: [instructeur]) }

      before do
        sign_in(instructeur.user)
        subject
      end

      context 'when instructeurs_self_management? is false' do
        let(:instructeurs_self_management_enabled) { false }
        it do
          expect(response.body).not_to have_link(href: admin_procedure_groupe_instructeurs_path(procedure))
          expect(response.body).not_to have_link(href: instructeur_groupes_path(procedure))
          expect(response.body).not_to have_link(href: instructeur_groupe_path(procedure, procedure.defaut_groupe_instructeur))
        end
      end

      context 'when instructeurs_self_management? is true' do
        let(:instructeurs_self_management_enabled) { true }
        it do
          expect(response.body).not_to have_link(href: admin_procedure_groupe_instructeurs_path(procedure))
          expect(response.body).to have_link(href: instructeur_groupes_path(procedure))
          expect(response.body).not_to have_link(href: instructeur_groupe_path(procedure, procedure.defaut_groupe_instructeur))
        end
      end

      context 'when instructeurs_self_management? is false but as owner of the procedure' do
        let(:instructeurs_self_management_enabled) { false }
        let(:administrateur) { create(:administrateur, user: instructeur.user) }
        let(:procedure) { create(:procedure, :expirable, instructeurs_self_management_enabled:, administrateurs: [administrateur], instructeurs: [instructeur]) }
        it do
          expect(response.body).to have_link(href: admin_procedure_groupe_instructeurs_path(procedure))
          expect(response.body).not_to have_link(href: instructeur_groupes_path(procedure))
          expect(response.body).not_to have_link(href: instructeur_groupe_path(procedure, procedure.defaut_groupe_instructeur))
        end
      end
    end

    context "when logged in, and belonging to gi_1, gi_2" do
      before do
        sign_in(instructeur.user)
        instructeur.groupe_instructeurs << gi_2
      end

      context 'when the procedure is discarded' do
        before do
          procedure.discard!
        end

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context "without any dossier" do
        before { subject }

        it do
          expect(response).to have_http_status(:ok)
          expect(assigns(:procedure)).to eq(procedure)
        end
      end

      context 'with a new dossier without follower' do
        let!(:new_unfollow_dossier) { create(:dossier, :en_instruction, procedure: procedure) }

        context do
          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_unfollow_dossier].map(&:id)) }
        end

        context 'with pagination' do
          let(:dossiers) { Array.new(26) { create(:dossier, :en_instruction, procedure: procedure) } }
          before do # warmup cache
            get :show, params: { procedure_id: procedure.id, statut: statut }
            dossiers
          end

          it 'keeps request count stable' do
            count_with_25, count_with_100 = 0, 0

            stub_const('Instructeurs::ProceduresController::ITEMS_PER_PAGE', 25)
            ActiveSupport::Notifications.subscribed(lambda { |*_args| count_with_25 += 1 }, "sql.active_record") do
              get :show, params: { procedure_id: procedure.id, statut: statut }
              expect(assigns(:projected_dossiers).size).to eq(25)
            end

            stub_const('Instructeurs::ProceduresController::ITEMS_PER_PAGE', 100)
            ActiveSupport::Notifications.subscribed(lambda { |*_args| count_with_100 += 1 }, "sql.active_record") do
              get :show, params: { procedure_id: procedure.id, statut: statut }
              expect(assigns(:projected_dossiers).size).to eq(dossiers.size + 1) # +1 due to let!(:new_unfollow_dossier)
            end

            expect(count_with_100).to eq(count_with_25)
          end
        end

        context 'with a dossier en contruction hidden by user' do
          let!(:hidden_dossier) { create(:dossier, :en_construction, groupe_instructeur: gi_2, hidden_by_user_at: 1.hour.ago) }
          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_unfollow_dossier].map(&:id)) }
        end

        context 'with a dossier en contruction not hidden by user' do
          let!(:en_construction_dossier) { create(:dossier, :en_construction, groupe_instructeur: gi_2) }
          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_unfollow_dossier, en_construction_dossier].map(&:id)) }
        end

        context 'and dossiers without follower on each of the others groups' do
          let!(:new_unfollow_dossier_on_gi_2) { create(:dossier, :en_instruction, groupe_instructeur: gi_2) }
          let!(:new_unfollow_dossier_on_gi_3) { create(:dossier, :en_instruction, groupe_instructeur: gi_3) }

          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_unfollow_dossier, new_unfollow_dossier_on_gi_2].map(&:id)) }
        end
      end

      context 'with a new dossier with a follower' do
        let(:statut) { 'suivis' }
        let!(:new_followed_dossier) { create(:dossier, :en_instruction, procedure: procedure, followers_instructeurs: [instructeur]) }

        context do
          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_followed_dossier].map(&:id)) }
        end

        context 'and dossier with a follower on each of the others groups' do
          let!(:new_follow_dossier_on_gi_2) { create(:dossier, :en_instruction, groupe_instructeur: gi_2, followers_instructeurs: [instructeur]) }
          let!(:new_follow_dossier_on_gi_3) { create(:dossier, :en_instruction, groupe_instructeur: gi_3, followers_instructeurs: [instructeur]) }

          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_followed_dossier, new_follow_dossier_on_gi_2].map(&:id)) }
        end
      end

      context 'with a termine dossier with a follower' do
        let(:statut) { 'traites' }
        let!(:termine_dossier) { create(:dossier, :accepte, procedure: procedure) }

        context do
          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([termine_dossier].map(&:id)) }
        end

        context 'and terminer dossiers on each of the others groups' do
          let!(:termine_dossier_on_gi_2) { create(:dossier, :accepte, groupe_instructeur: gi_2) }
          let!(:termine_dossier_on_gi_3) { create(:dossier, :accepte, groupe_instructeur: gi_3) }

          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([termine_dossier, termine_dossier_on_gi_2].map(&:id)) }
        end

        context 'with batch operations' do
          let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [termine_dossier], instructeur: instructeur) }
          let!(:termine_dossier_2) { create(:dossier, :accepte, procedure: procedure) }
          let!(:batch_operation_2) { create(:batch_operation, operation: :archiver, dossiers: [termine_dossier_2], instructeur: instructeur) }

          before { subject }

          it { expect(assigns(:batch_operations)).to match_array([batch_operation, batch_operation_2]) }
        end

        context 'with a dossier in a groupe instructeur where current instructeur is not ' do
          let(:instructeur_2) { create(:instructeur) }
          let!(:termine_dossier) { create(:dossier, :accepte, procedure: procedure, groupe_instructeur: gi_3) }
          let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [termine_dossier], instructeur: instructeur_2) }

          before { subject }

          it { expect(assigns(:batch_operations)).to eq([]) }
        end
      end

      context 'with an archived dossier' do
        let(:statut) { 'archives' }
        let!(:archived_dossier) { create(:dossier, :en_instruction, procedure: procedure, archived: true) }
        let!(:archived_dossier_deleted) { create(:dossier, :en_instruction, procedure: procedure, archived: true, hidden_by_administration_at: 2.days.ago) }

        context do
          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([archived_dossier].map(&:id)) }
        end

        context 'and terminer dossiers on each of the others groups' do
          let!(:archived_dossier_on_gi_2) { create(:dossier, :en_instruction, groupe_instructeur: gi_2, archived: true) }
          let!(:archived_dossier_on_gi_3) { create(:dossier, :en_instruction, groupe_instructeur: gi_3, archived: true) }

          before { subject }

          it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([archived_dossier, archived_dossier_on_gi_2].map(&:id)) }
        end
      end

      context 'with an expirants dossier' do
        let(:statut) { 'expirant' }
        let!(:expiring_dossier_termine_deleted) { create(:dossier, :accepte, procedure: procedure, processed_at: 175.days.ago, hidden_by_administration_at: 2.days.ago).tap(&:update_expired_at) }
        let!(:expiring_dossier_termine) { create(:dossier, :accepte, procedure: procedure, processed_at: 175.days.ago).tap(&:update_expired_at) }
        let!(:expiring_dossier_en_construction) { create(:dossier, :en_construction, procedure: procedure, en_construction_at: 175.days.ago).tap(&:update_expired_at) }

        before { subject }

        it { expect(assigns(:filtered_sorted_paginated_ids)).to match_array([expiring_dossier_termine, expiring_dossier_en_construction].map(&:id)) }
      end

      describe 'statut' do
        let!(:a_suivre_dossier) { travel_to(1.day.ago) { create(:dossier, :en_instruction, procedure: procedure) } }
        let!(:new_followed_dossier) { travel_to(2.days.ago) { create(:dossier, :en_instruction, procedure: procedure) } }
        let!(:termine_dossier) { travel_to(3.days.ago) { create(:dossier, :accepte, procedure: procedure) } }
        let!(:archived_dossier) { travel_to(4.days.ago) { create(:dossier, :en_instruction, procedure: procedure, archived: true) } }

        before do
          instructeur.followed_dossiers << new_followed_dossier
          subject
        end

        context 'when statut is empty' do
          let(:statut) { nil }

          it do
            expect(assigns(:filtered_sorted_paginated_ids)).to match_array([a_suivre_dossier].map(&:id))
            expect(assigns(:statut)).to eq('a-suivre')
          end
        end

        context 'when statut is a-suivre' do
          let(:statut) { 'a-suivre' }

          it do
            expect(assigns(:statut)).to eq('a-suivre')
            expect(assigns(:filtered_sorted_paginated_ids)).to match_array([a_suivre_dossier].map(&:id))
          end
        end

        context 'when statut is suivis' do
          let(:statut) { 'suivis' }

          it do
            expect(assigns(:statut)).to eq('suivis')
            expect(assigns(:filtered_sorted_paginated_ids)).to match_array([new_followed_dossier].map(&:id))
          end
        end

        context 'when statut is traites' do
          let(:statut) { 'traites' }

          it do
            expect(assigns(:statut)).to eq('traites')
            expect(assigns(:filtered_sorted_paginated_ids)).to match_array([termine_dossier].map(&:id))
          end
        end

        context 'when statut is tous' do
          let(:statut) { 'tous' }

          it do
            expect(assigns(:statut)).to eq('tous')
            expect(assigns(:filtered_sorted_paginated_ids)).to match_array([a_suivre_dossier, new_followed_dossier, termine_dossier].map(&:id))
          end
        end

        context 'when statut is archives' do
          let(:statut) { 'archives' }

          it do
            expect(assigns(:statut)).to eq('archives')
            expect(assigns(:filtered_sorted_paginated_ids)).to match_array([archived_dossier].map(&:id))
          end
        end
      end

      context 'when an error occurs in the DossierFilterService' do
        before do
          allow(DossierFilterService).to receive(:filtered_sorted_ids).and_raise(ActiveRecord::StatementInvalid.new('PG::UndefinedFunction'))

          expect_any_instance_of(ProcedurePresentation).to receive(:destroy_filters_for!)
          subject
        end

        it do
          expect(response).to redirect_to(instructeur_procedure_path)
          expect(flash.alert).to include('Votre affichage a dû être réinitialisé')
        end
      end

      context 'exports notification' do
        context 'without generated export' do
          before do
            create(:export, :pending, groupe_instructeurs: [gi_2])

            subject
          end

          it { expect(assigns(:has_export_notification)).to be(false) }
        end

        context 'with generated export' do
          render_views
          before do
            create(:export, :generated, groupe_instructeurs: [gi_2], updated_at: 1.minute.ago)

            if exports_seen_at
              cookies.encrypted["exports_#{procedure.id}_seen_at"] = exports_seen_at.to_datetime.to_s
            end

            subject
          end

          context 'without cookie' do
            let(:exports_seen_at) { nil }
            it { expect(assigns(:has_export_notification)).to be(true) }
          end

          context 'with cookie in past' do
            let(:exports_seen_at) { 1.hour.ago }
            it do
              expect(assigns(:has_export_notification)).to be(true)
              expect(response.body).to match(/Un nouvel export est prêt/)
            end
          end

          context 'with cookie set after last generated export' do
            let(:exports_seen_at) { 10.seconds.ago }
            it { expect(assigns(:has_export_notification)).to be(false) }
          end
        end
      end

      context 'exports alert' do
        context 'without generated export' do
          let(:statut) { 'tous' }
          let!(:export) { create(:export, :pending, groupe_instructeurs: [gi_2]) }
          render_views
          before do
            subject
          end

          it do
            expect(assigns(:last_export)).to eq(export)
            expect(response.body).to include("Votre dernier export est en cours de création")
          end

          context 'when export is generated but file not yet attached' do
            let!(:export) { create(:export, :generated, groupe_instructeurs: [gi_2]) }
            it { expect(response.body).to include("Votre dernier export est en cours de création") }
          end
        end

        context 'with recent generated export' do
          let(:statut) { 'tous' }
          let!(:export) { create(:export, :generated, groupe_instructeurs: [gi_2], updated_at: 1.minute.ago) }
          render_views
          before do
            export.file.attach(io: StringIO.new('export'), filename: 'file.csv')
            subject
          end

          it do
            expect(assigns(:last_export)).to eq(export)
            expect(response.body).to include("Votre dernier export au format csv est prêt")
          end
        end

        context 'with failed export ' do
          let(:statut) { 'tous' }
          let!(:export) { create(:export, :failed, groupe_instructeurs: [gi_2], updated_at: 1.minute.ago) }
          render_views
          before do
            subject
          end

          it do
            expect(assigns(:last_export)).to eq(export)
            expect(response.body).to include("Votre dernier export au format csv n’a pas fonctionné")
          end
        end

        context 'with export more than hour ago' do
          let(:statut) { 'tous' }
          let!(:export) { create(:export, :generated, groupe_instructeurs: [gi_2], updated_at: 2.hours.ago) }
          before do
            subject
          end

          it { expect(assigns(:last_export)).to eq(nil) }
        end

        context 'logged in with another instructeur' do
          let(:instructeur_2) { create(:instructeur) }
          let(:statut) { 'tous' }
          let!(:export) { create(:export, :generated, groupe_instructeurs: [gi_2], updated_at: 1.minute.ago) }

          before do
            sign_in(instructeur_2.user)
            instructeur_2.groupe_instructeurs << gi_2
            subject
          end

          it { expect(assigns(:last_export)).to eq(nil) }
        end
      end

      context 'dossier labels' do
        let(:procedure) { create(:procedure, :with_labels, instructeurs: [instructeur]) }
        let!(:dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur: gi_2) }
        let!(:dossier_2) { create(:dossier, :en_construction, procedure:, groupe_instructeur: gi_2) }
        let(:statut) { 'tous' }
        let(:label_id) { procedure.find_column(label: 'Labels') }
        let!(:procedure_presentation) do
          ProcedurePresentation.create!(assign_to: AssignTo.first)
        end
        render_views

        before do
          DossierLabel.create(dossier_id: dossier.id, label_id: dossier.procedure.labels.first.id)
          DossierLabel.create(dossier_id: dossier.id, label_id: dossier.procedure.labels.second.id)
          DossierLabel.create(dossier_id: dossier_2.id, label_id: dossier.procedure.labels.last.id)

          procedure_presentation.update(displayed_columns: [
            label_id.id,
          ])

          subject
        end

        it 'displays correctly labels in instructeur table' do
          expect(response.body).to include("Labels")
          expect(response.body).to have_selector('ul.fr-tags-group li span.fr-tag', text: 'À examiner')
          expect(response.body).to have_selector('ul.fr-tags-group li span.fr-tag', text: 'À relancer')
          expect(response.body).not_to have_selector('ul li span.fr-tag', text: 'Urgent')
          expect(response.body).to have_selector('span.fr-tag', text: 'Urgent')
        end
      end

      context 'when ProConnect is required' do
        before do
          procedure.update!(pro_connect_restriction: :instructeurs)
        end

        it 'redirects to pro_connect_path and sets a flash message' do
          subject

          expect(response).to redirect_to(pro_connect_path)
          expect(flash[:alert]).to eq("Vous devez vous connecter par ProConnect pour accéder à cette démarche")
        end

        context "and the cookie is set" do
          before do
            cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { value: { user_id: instructeur.user.id }.to_json }
          end

          it "does not redirect to pro_connect_path" do
            subject

            expect(response).not_to redirect_to(pro_connect_path)
          end
        end
      end
    end

    describe 'caches statut and page query param' do
      let(:statut) { 'tous' }
      let(:page) { '1' }
      let!(:dossier) { create(:dossier, :accepte, procedure:) }
      before { sign_in(instructeur.user) }
      subject { get :show, params: { procedure_id: procedure.id, statut:, page: } }
      it 'changes cached value' do
        expect { subject }.to change { Cache::ProcedureDossierPagination.new(statut:, procedure_presentation: double(procedure:, instructeur:)).send(:read_cache) }
          .from({}).to(ids: [dossier.id], incoming_page: page)
      end
    end

    describe 'archived dossiers count calculation' do
      let(:statut) { 'tous' }
      let!(:en_instruction_dossier) { create(:dossier, :en_instruction, procedure: procedure) }
      let!(:archived_dossier_1) { create(:dossier, :en_instruction, procedure: procedure, archived: true) }
      let!(:archived_dossier_2) { create(:dossier, :accepte, procedure: procedure, archived: true) }
      let!(:archived_dossier_3) { create(:dossier, :en_instruction, procedure: procedure, archived: true, hidden_by_administration_at: 1.day.ago) }

      before do
        sign_in(instructeur.user)
      end

      it 'calculates archived dossiers count correctly when statut is tous' do
        subject

        expect(assigns(:archived_dossiers_count)).to eq(2)
      end

      context 'when there is a filter' do
        let(:filter) { FilteredColumn.new(column: procedure.find_column(label: "État du dossier"), filter: 'en_instruction') }

        let!(:procedure_presentation) do
          create(:procedure_presentation, assign_to: instructeur.assign_to.first, tous_filters: [filter])
        end

        it 'counts only the archived dossiers that match the filter' do
          subject

          expect(assigns(:archived_dossiers_count)).to eq(1)
        end
      end

      context 'when statut is not tous' do
        let(:statut) { 'a-suivre' }

        it 'sets archived dossiers count to 0' do
          subject

          expect(assigns(:archived_dossiers_count)).to eq(0)
        end
      end
    end
  end

  describe '#deleted_dossiers' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, instructeurs: [instructeur]) }
    let(:deleted_dossier) { create(:deleted_dossier, procedure: procedure, state: :en_construction) }

    before do
      sign_in(instructeur.user)
      get :deleted_dossiers, params: { procedure_id: procedure.id }
    end

    it { expect(assigns(:deleted_dossiers)).to match_array([deleted_dossier]) }
  end

  describe '#update_email_notifications' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, instructeurs: [instructeur]) }

    context "when logged in" do
      before { sign_in(instructeur.user) }

      context 'when the instructeur update its preferences' do
        let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:) }

        before do
          patch :update_email_notifications, params: {
            procedure_id: procedure.id,
            instructeurs_procedure: {
              id: instructeur_procedure.id,
              daily_email_summary: true,
              weekly_email_summary: false,
              instant_email_new_dossier: false,
              instant_email_new_message: false,
              instant_email_new_expert_avis: false,
            },
          }
        end

        it do
          instructeur_procedure.reload
          expect(instructeur_procedure.daily_email_summary).to eq(true)
          expect(instructeur_procedure.weekly_email_summary).to eq(false)
          expect(instructeur_procedure.instant_email_new_dossier).to eq(false)
          expect(instructeur_procedure.instant_email_new_message).to eq(false)
          expect(instructeur_procedure.instant_email_new_expert_avis).to eq(false)
        end
      end
    end
  end

  describe '#email_usagers' do
    let(:procedure) { create(:procedure) }

    subject do
      get :email_usagers, params: { procedure_id: procedure.id }
    end

    it { is_expected.to redirect_to(new_user_session_path) }

    context 'when authenticated' do
      before { sign_in(instructeur.user) }

      context 'the procedure is not routed (or not)' do
        let(:instructeur) { create(:instructeur) }
        let(:defaut_groupe_instructeur) { procedure.defaut_groupe_instructeur }
        let!(:dossier_in_group) { create(:dossier, :brouillon, procedure:, groupe_instructeur: defaut_groupe_instructeur) }
        let!(:dossier_without_groupe) { create(:dossier, :brouillon, procedure:, groupe_instructeur: nil) }
        before { defaut_groupe_instructeur.instructeurs << instructeur }

        it 'count brouillon per group and not in group' do
          is_expected.to have_http_status(200)
          expect(assigns(:dossiers_count_per_groupe_instructeur)).to match({ nil => 1, defaut_groupe_instructeur.id => 1 }) # only dossier_in_group
        end
      end
    end
  end

  describe '#create_multiple_commentaire_for_brouillons' do
    let(:instructeur) { create(:instructeur) }
    let(:body) { "avant\napres" }
    let(:bulk_message) { BulkMessage.first }

    before do
      sign_in(instructeur.user)
      procedure
    end

    context 'when routing not enabled' do
      let(:procedure) { create(:procedure, :published, instructeurs: [instructeur], routing_enabled: false) }
      let!(:dossier) { create(:dossier, :brouillon, procedure:) }
      let!(:dossier_2) { create(:dossier, :brouillon, procedure:) }
      let!(:dossier_3) { create(:dossier, :brouillon, procedure:) }
      let!(:dossier_4) { create(:dossier, :brouillon, procedure:) }

      it "creates commentaires for all dossiers, dossier.groupe_instructeur does not matter" do
        expect do
            post :create_multiple_commentaire_for_brouillons,
              params: {
                procedure_id: procedure.id,
                bulk_message: { body: body },
              }
          end.to change { Commentaire.count }.from(0).to(4)
        [dossier, dossier_2, dossier_3, dossier_4].each do |any_dossier|
          expect(any_dossier.commentaires.first.body).to eq("avant\napres")
        end
      end
    end

    context 'when routing_enabled' do
      let!(:procedure) { create(:procedure, :published, instructeurs: [instructeur]) }

      let!(:gi_p1_2) { create(:groupe_instructeur, label: '2', procedure: procedure) }
      let!(:gi_p1_1) { create(:groupe_instructeur, label: '1', procedure: procedure, instructeurs: [instructeur]) }
      let!(:dossier) { create(:dossier, state: "brouillon", procedure: procedure, groupe_instructeur: gi_p1_1) }
      let!(:dossier_2) { create(:dossier, state: "brouillon", procedure: procedure, groupe_instructeur: gi_p1_1) }
      let!(:dossier_3) { create(:dossier, state: "brouillon", procedure: procedure, groupe_instructeur: gi_p1_2) }
      let!(:dossier_4) { create(:dossier, state: "brouillon", procedure: procedure, groupe_instructeur: nil) }

      context 'when groupe instructeur id is specified' do
        subject do
          post :create_multiple_commentaire_for_brouillons,
                params: {
                  procedure_id: procedure.id,
                  bulk_message: {
                    body: body,
                    groupe_instructeur_ids: { gi_p1_1.id => true, gi_p1_2.id => false },
                  },
                }
        end
        it "creates a Bulk Message for given group_instructeur_ids" do
          expect { subject }.to change { Commentaire.count }.from(0).to(2)
          expect(dossier.commentaires.first.body).to eq(body)
          expect(dossier_2.commentaires.first.body).to eq(body)
          expect(dossier_3.commentaires.count).to eq(0)
          expect(dossier_4.commentaires.count).to eq(0)
          expect(flash.notice).to be_present
          expect(flash.notice).to eq("Tous les messages ont été envoyés avec succès")
          expect(response).to redirect_to instructeur_procedure_path(procedure)
        end
      end

      context 'when without_group is specified' do
        subject do
          post :create_multiple_commentaire_for_brouillons,
          params: {
            procedure_id: procedure.id,
            bulk_message: {
              body: body,
              groupe_instructeur_ids: {},
              without_group: "1",
            },
          }
        end
        it "creates a Bulk Message for dossier without group_instructeur_ids" do
          expect { subject }.to change { Commentaire.count }.from(0).to(1)
          expect(dossier.commentaires.count).to eq(0)
          expect(dossier_2.commentaires.count).to eq(0)
          expect(dossier_3.commentaires.count).to eq(0)
          expect(dossier_4.commentaires.first.body).to eq(body)
          expect(flash.notice).to be_present
          expect(flash.notice).to eq("Tous les messages ont été envoyés avec succès")
          expect(response).to redirect_to instructeur_procedure_path(procedure)
        end
      end
    end
  end

  describe '#download_export' do
    let(:instructeur) { create(:instructeur) }
    let!(:procedure) { create(:procedure) }
    let!(:assign_to) { create(:assign_to, instructeur: instructeur, groupe_instructeur: build(:groupe_instructeur, procedure: procedure), manager: manager) }
    let!(:gi_0) { assign_to.groupe_instructeur }
    let!(:gi_1) { create(:groupe_instructeur, label: 'gi_1', procedure: procedure, instructeurs: [instructeur]) }
    let(:manager) { false }
    before { sign_in(instructeur.user) }

    subject do
      get :download_export, params: { export_format: :csv, procedure_id: procedure.id }
    end

    context 'when the export does not exist' do
      it 'displays an notice' do
        is_expected.to redirect_to(exports_instructeur_procedure_url(procedure))
        expect(flash.notice).to be_present
      end

      it { expect { subject }.to change { Export.where(user_profile: instructeur).count }.by(1) }

      context 'with an export template' do
        let(:export_template) { create(:export_template) }
        subject do
          get :download_export, params: { export_template_id: export_template.id, procedure_id: procedure.id }
        end

        it 'displays an notice' do
          is_expected.to redirect_to(exports_instructeur_procedure_url(procedure))
          expect(flash.notice).to be_present
        end
      end
    end

    context 'when the export is not ready' do
      before do
        create(:export, groupe_instructeurs: [gi_1])
      end

      it 'displays an notice' do
        is_expected.to redirect_to(exports_instructeur_procedure_url(procedure))
        expect(flash.notice).to be_present
      end
    end

    context 'when the export is ready' do
      let(:export) { create(:export, groupe_instructeurs: [gi_1, gi_0], job_status: 'generated') }

      before do
        export.file.attach(io: StringIO.new('export'), filename: 'file.csv')
      end

      it 'displays the download link' do
        subject
        expect(response.headers['Location']).to start_with("http://test.host/rails/active_storage/disk")
      end
    end

    context 'when another export is ready' do
      let(:export) { create(:export, groupe_instructeurs: [gi_0]) }

      before do
        export.file.attach(io: StringIO.new('export'), filename: 'file.csv')
      end

      it 'displays an notice' do
        is_expected.to redirect_to(exports_instructeur_procedure_url(procedure))
        expect(flash.notice).to be_present
      end
    end

    context 'when the turbo_stream format is used' do
      render_views

      before do
        post :download_export,
          params: { export_format: :csv, procedure_id: procedure.id, statut: 'traites' },
          format: :turbo_stream
      end

      it 'responds in the correct format' do
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(polling_last_export_instructeur_procedure_path(procedure))
      end
    end

    context 'when logged in through super admin' do
      let(:manager) { true }
      it { is_expected.to have_http_status(:forbidden) }
    end
  end

  describe '#export_templates' do
    render_views

    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure) }
    let(:groupe_instructeur) { create(:groupe_instructeur, procedure: procedure) }
    let!(:export_template) { create(:export_template, name: "My Template", groupe_instructeur: groupe_instructeur) }

    before do
      sign_in(instructeur.user)
      create(:assign_to, instructeur: instructeur, groupe_instructeur: groupe_instructeur)
    end

    it 'displays export templates' do
      get :export_templates, params: { procedure_id: procedure.id }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Template")
    end
  end

  describe '#exports' do
    let(:instructeur) { create(:instructeur) }
    let!(:procedure) { create(:procedure) }
    let!(:assign_to) { create(:assign_to, instructeur: instructeur, groupe_instructeur: build(:groupe_instructeur, procedure: procedure), manager: manager) }
    let!(:gi_0) { assign_to.groupe_instructeur }
    let!(:gi_1) { create(:groupe_instructeur, label: 'gi_1', procedure: procedure, instructeurs: [instructeur]) }
    let(:manager) { false }
    before { sign_in(instructeur.user) }

    subject do
      get :exports, params: { procedure_id: procedure.id }
    end

    context 'when there is one export in the instructeurs group' do
      let!(:export) { create(:export, groupe_instructeurs: [gi_1]) }
      it 'retrieves the export' do
        subject
        expect(assigns(:exports)).to eq([export])
      end
    end

    context 'when there is one export in another instructeurs group' do
      let!(:instructeur_2) { create(:instructeur) }
      let!(:gi_2) { create(:groupe_instructeur, label: 'gi_2', procedure: procedure, instructeurs: [instructeur_2]) }
      let!(:export) { create(:export, groupe_instructeurs: [gi_2]) }
      it 'does not retrieved the export' do
        subject
        expect(assigns(:exports)).to eq([])
      end
    end

    context 'when logged in through super admin' do
      let(:manager) { true }
      it { is_expected.to have_http_status(:forbidden) }
    end
  end

  describe '#preview' do
    render_views

    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, types_de_champ_public: [type: :text, libelle: "Premier champ"]) }

    before do
      sign_in(instructeur.user)
      create(:groupe_instructeur, procedure:, instructeurs: [instructeur])
    end

    it 'displays preview' do
      get :apercu, params: { procedure_id: procedure.id }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Premier champ")
      expect(response.body).not_to include("Déposer")
      expect(assigns(:preview_service)).to be_a(DossierPreviewService)
    end
  end

  describe '#select_procedure' do
    let(:instructeur) { create(:instructeur) }

    before do
      sign_in(instructeur.user)
    end

    context 'when procedure_id is present' do
      let(:procedure) { create(:procedure) }

      it 'redirects to the procedure path' do
        puts "procedure.id: #{procedure.id}"
        get :select_procedure, params: { procedure_id: procedure.id }

        expect(response).to redirect_to(instructeur_procedure_path(procedure_id: procedure.id))
      end
    end

    context 'when procedure_id is not present' do
      it 'redirects to procedures index' do
        get :select_procedure

        expect(response).to redirect_to(instructeur_procedures_path)
      end
    end

    context 'when procedure_id is empty string' do
      it 'redirects to procedures index' do
        get :select_procedure, params: { procedure_id: '' }

        expect(response).to redirect_to(instructeur_procedures_path)
      end
    end

    context 'when procedure_id is nil' do
      it 'redirects to procedures index' do
        get :select_procedure, params: { procedure_id: nil }

        expect(response).to redirect_to(instructeur_procedures_path)
      end
    end
  end

  describe '#history' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published) }

    before do
      sign_in(instructeur.user)
      create(:groupe_instructeur, procedure: procedure, instructeurs: [instructeur])
      procedure.revisions.update_all(published_at: nil)
    end

    context 'when there are no published revisions' do
      before do
        get :history, params: { procedure_id: procedure.id }
      end

      it 'assigns an empty revisions array' do
        expect(assigns(:revisions)).to be_empty
      end

      it 'creates an instructeur_procedure record if it does not exist' do
        expect(assigns(:instructeur_procedure)).to be_present
        expect(assigns(:instructeur_procedure).instructeur).to eq(instructeur)
        expect(assigns(:instructeur_procedure).procedure).to eq(procedure)
      end
    end

    context 'when there is only one published revision' do
      let!(:revision) { create(:procedure_revision, procedure: procedure, published_at: 1.day.ago) }

      before do
        procedure.update(published_revision_id: revision.id)
        get :history, params: { procedure_id: procedure.id }
      end

      it 'assigns a revisions array with one revision' do
        expect(assigns(:revisions).length).to eq(1)
        expect(assigns(:revisions).first).to eq(revision)
      end

      it 'updates the last_revision_seen_id in instructeur_procedure' do
        expect(assigns(:instructeur_procedure).last_revision_seen_id).to eq(revision.id)
      end
    end

    context 'when there are two published revisions' do
      let!(:old_revision) { create(:procedure_revision, procedure: procedure, published_at: 2.days.ago) }
      let!(:new_revision) { create(:procedure_revision, procedure: procedure, published_at: 1.day.ago) }

      before do
        procedure.update(published_revision_id: new_revision.id)
        get :history, params: { procedure_id: procedure.id }
      end

      it 'assigns a revisions array with both revisions' do
        expect(assigns(:revisions).length).to eq(2)
      end

      it 'orders revisions with the most recent first' do
        revisions = assigns(:revisions)
        expect(revisions[0]).to eq(new_revision)
        expect(revisions[1]).to eq(old_revision)
      end
    end

    context 'when there are multiple published revisions' do
      let!(:oldest_revision) { create(:procedure_revision, procedure: procedure, published_at: 4.days.ago) }
      let!(:middle_revision) { create(:procedure_revision, procedure: procedure, published_at: 3.days.ago) }
      let!(:recent_revision) { create(:procedure_revision, procedure: procedure, published_at: 2.days.ago) }
      let!(:newest_revision) { create(:procedure_revision, procedure: procedure, published_at: 1.day.ago) }

      before do
        procedure.update(published_revision_id: newest_revision.id)
        get :history, params: { procedure_id: procedure.id }
      end

      it 'assigns a revisions array with all published revisions' do
        expect(assigns(:revisions).length).to eq(4)
      end

      it 'orders revisions with the most recent first' do
        revisions = assigns(:revisions)
        expect(revisions[0]).to eq(newest_revision)
        expect(revisions[1]).to eq(recent_revision)
        expect(revisions[2]).to eq(middle_revision)
        expect(revisions[3]).to eq(oldest_revision)
      end
    end

    context 'when there are published and unpublished revisions' do
      let!(:published_old) { create(:procedure_revision, procedure: procedure, published_at: 3.days.ago) }
      let!(:unpublished) { create(:procedure_revision, procedure: procedure, published_at: nil) }
      let!(:published_new) { create(:procedure_revision, procedure: procedure, published_at: 1.day.ago) }

      before do
        procedure.update(published_revision_id: published_new.id)
        get :history, params: { procedure_id: procedure.id }
      end

      it 'only includes published revisions' do
        revisions = assigns(:revisions)
        expect(revisions.length).to eq(2)
        expect(revisions).to include(published_new)
        expect(revisions).to include(published_old)
        expect(revisions).not_to include(unpublished)
      end
    end

    context 'when instructeur_procedure does not exist' do
      let!(:revision) { create(:procedure_revision, procedure: procedure, published_at: 1.day.ago) }

      before do
        procedure.update(published_revision_id: revision.id)
        # Make sure no instructeur_procedure exists
        InstructeursProcedure.where(instructeur: instructeur, procedure: procedure).destroy_all

        get :history, params: { procedure_id: procedure.id }
      end

      it 'creates a new instructeur_procedure record' do
        expect(assigns(:instructeur_procedure)).to be_present
        expect(assigns(:instructeur_procedure).instructeur).to eq(instructeur)
        expect(assigns(:instructeur_procedure).procedure).to eq(procedure)
        expect(assigns(:instructeur_procedure).last_revision_seen_id).to eq(revision.id)
      end
    end
  end

  describe '#mark_latest_revision_as_seen' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published) }

    before do
      sign_in(instructeur.user)
      create(:groupe_instructeur, procedure: procedure, instructeurs: [instructeur])
      create(:instructeurs_procedure, instructeur: instructeur, procedure: procedure, last_revision_seen_id: nil)
    end

    context 'when there is no published revision' do
      before do
        procedure.revisions.update_all(published_at: nil)
        procedure.update(published_revision_id: nil)
        get :history, params: { procedure_id: procedure.id }
      end

      it 'does not update last_revision_seen_id' do
        expect(assigns(:instructeur_procedure).last_revision_seen_id).to be_nil
      end
    end

    context 'when there is a published revision' do
      let!(:revision) { create(:procedure_revision, procedure: procedure, published_at: 1.day.ago) }

      before do
        procedure.update(published_revision_id: revision.id)
      end

      it 'updates last_revision_seen_id when viewing history page' do
        get :history, params: { procedure_id: procedure.id }

        expect(assigns(:instructeur_procedure).last_revision_seen_id).to eq(revision.id)
      end

      context 'when already seen the latest revision' do
        before do
          instructeur_procedure = InstructeursProcedure.find_by(instructeur: instructeur, procedure: procedure)
          instructeur_procedure.update(last_revision_seen_id: revision.id)

          get :history, params: { procedure_id: procedure.id }
        end

        it 'does not change last_revision_seen_id' do
          expect(assigns(:instructeur_procedure).last_revision_seen_id).to eq(revision.id)
        end
      end

      context 'when a new revision is published' do
        let!(:new_revision) { create(:procedure_revision, procedure: procedure, published_at: 1.hour.ago) }

        before do
          instructeur_procedure = InstructeursProcedure.find_by(instructeur: instructeur, procedure: procedure)
          instructeur_procedure.update(last_revision_seen_id: revision.id)

          procedure.update(published_revision_id: new_revision.id)
          get :history, params: { procedure_id: procedure.id }
        end

        it 'updates last_revision_seen_id to the latest published revision' do
          expect(assigns(:instructeur_procedure).last_revision_seen_id).to eq(new_revision.id)
        end
      end
    end
  end
end
