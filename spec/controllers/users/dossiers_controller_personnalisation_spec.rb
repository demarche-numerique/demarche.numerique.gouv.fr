# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  describe 'GET #personnalisation' do
    let(:user) { create(:user) }
    before { sign_in(user) }

    context 'when feature disabled' do
      it 'redirects to dossiers' do
        get :personnalisation
        expect(response).to redirect_to(dossiers_path)
      end
    end

    context 'when feature enabled' do
      before { Flipper.enable(:dossiers_list_personnalisation, user) }

      context 'with 5 or fewer dossiers' do
        before { create_list(:dossier, 5, user:) }

        it 'redirects to dossiers' do
          get :personnalisation
          expect(response).to redirect_to(dossiers_path)
        end
      end

      context 'with more than 5 dossiers' do
        before { create_list(:dossier, 6, user:) }

        it 'renders the personnalisation screen' do
          get :personnalisation
          expect(response).to have_http_status(:ok)
        end
      end

      context 'with dossiers received by invitation only' do
        let(:invited_procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Ville' }]) }

        before do
          create_list(:dossier, 6, :en_construction, procedure: invited_procedure).each do |dossier|
            create(:invite, dossier:, user:)
          end
        end

        it 'renders the screen and exposes procedures seen through invitation' do
          get :personnalisation
          expect(response).to have_http_status(:ok)
          expect(assigns(:personnalisable_procedures)).to eq([invited_procedure])
        end
      end

      context 'with a procedure without personnalisable champ' do
        let(:eligible_procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Ville' }]) }
        let(:non_eligible_procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :textarea, libelle: 'Description' }]) }

        before do
          create_list(:dossier, 3, user:, procedure: eligible_procedure)
          create_list(:dossier, 3, user:, procedure: non_eligible_procedure)
        end

        it 'only exposes procedures with personnalisable champs' do
          get :personnalisation
          expect(assigns(:personnalisable_procedures)).to eq([eligible_procedure])
        end
      end

      context 'when no procedure has personnalisable champs' do
        render_views

        let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :textarea, libelle: 'Description' }]) }

        before { create_list(:dossier, 6, user:, procedure:) }

        it 'renders an empty state instead of the form' do
          get :personnalisation
          expect(response.body).to include(I18n.t('views.users.dossiers.personnalisation.empty_state'))
          expect(response.body).not_to include('personnalisation-form')
        end
      end

      context 'query count does not grow with number of procedures' do
        render_views

        let(:procedure1) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Champ A' }]) }
        let(:procedure2) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Champ B' }]) }
        let(:procedure3) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Champ C' }]) }

        before do
          create_list(:dossier, 3, user:, procedure: procedure1)
          create_list(:dossier, 3, user:, procedure: procedure2)
          get :personnalisation # warmup: populate schema cache and Flipper cache
        end

        it 'issues the same number of queries for 2 vs 3 procedures' do
          count_2_procedures = 0
          ActiveSupport::Notifications.subscribed(lambda { |*_args| count_2_procedures += 1 }, "sql.active_record") do
            get :personnalisation
          end

          create_list(:dossier, 3, user:, procedure: procedure3)

          count_3_procedures = 0
          ActiveSupport::Notifications.subscribed(lambda { |*_args| count_3_procedures += 1 }, "sql.active_record") do
            get :personnalisation
          end

          expect(count_3_procedures).to eq(count_2_procedures)
        end
      end
    end
  end

  describe 'PATCH #update_personnalisation' do
    let(:user) { create(:user) }
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Ville' }]) }
    let(:column) { procedure.customizable_columns.first }

    before do
      Flipper.enable(:dossiers_list_personnalisation, user)
      create_list(:dossier, 6, user:, procedure:)
      sign_in(user)
    end

    it 'persists the chosen columns for the procedure and redirects with a notice' do
      patch :update_personnalisation, params: {
        personnalisations: { procedure.id.to_s => { displayed_columns: [column.id] } },
      }

      expect(response).to redirect_to(dossiers_path)
      perso = DossiersListPersonnalisation.find_by(user:, procedure:)
      expect(perso.displayed_columns.map(&:id)).to eq([column.id])
    end

    it 'persists the personnalisation for a procedure seen through invitation' do
      invited_procedure = create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Région' }])
      invited_dossier = create(:dossier, :en_construction, procedure: invited_procedure)
      create(:invite, dossier: invited_dossier, user:)
      invited_column = invited_procedure.customizable_columns.first

      patch :update_personnalisation, params: {
        personnalisations: { invited_procedure.id.to_s => { displayed_columns: [invited_column.id] } },
      }

      perso = DossiersListPersonnalisation.find_by(user:, procedure: invited_procedure)
      expect(perso.displayed_columns.map(&:id)).to eq([invited_column.id])
    end

    it 'ignores empty selections sent by the React combobox' do
      patch :update_personnalisation, params: {
        personnalisations: { procedure.id.to_s => { displayed_columns: [''] } },
      }

      perso = DossiersListPersonnalisation.find_by(user:, procedure:)
      expect(perso&.displayed_columns || []).to eq([])
    end

    it 'alerts instead of confirming when the personnalisation cannot be saved' do
      allow_any_instance_of(DossiersListPersonnalisation).to receive(:update).and_return(false)

      patch :update_personnalisation, params: {
        personnalisations: { procedure.id.to_s => { displayed_columns: [column.id] } },
      }

      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to eq(I18n.t('views.users.dossiers.personnalisation.error'))
    end

    context 'with forged column ids' do
      include Logic

      it 'does not persist a private annotation column' do
        procedure_with_private = create(:procedure, :published,
          public_type_de_champs: [{ type: :text, libelle: 'Ville' }],
          private_type_de_champs: [{ type: :text, libelle: 'Note instructeur' }])
        create(:dossier, user:, procedure: procedure_with_private)
        private_column = procedure_with_private.columns.find { _1.label == 'Note instructeur' }

        patch :update_personnalisation, params: {
          personnalisations: { procedure_with_private.id.to_s => { displayed_columns: [private_column.id] } },
        }

        perso = DossiersListPersonnalisation.find_by(user:, procedure: procedure_with_private)
        expect(perso&.displayed_columns || []).to eq([])
      end

      it 'does not persist a conditional champ column' do
        procedure_with_condition = create(:procedure, :published, public_type_de_champs: [
          { type: :yes_no, libelle: 'Gate', stable_id: 1 },
          { type: :text, libelle: 'Conditionné', condition: ds_eq(champ_value(1), constant(true)) },
        ])
        create(:dossier, user:, procedure: procedure_with_condition)
        conditional_column = procedure_with_condition.columns.find { _1.label == 'Conditionné' }

        patch :update_personnalisation, params: {
          personnalisations: { procedure_with_condition.id.to_s => { displayed_columns: [conditional_column.id] } },
        }

        perso = DossiersListPersonnalisation.find_by(user:, procedure: procedure_with_condition)
        expect(perso&.displayed_columns || []).to eq([])
      end

      it 'ignores a column id that is not valid JSON' do
        patch :update_personnalisation, params: {
          personnalisations: { procedure.id.to_s => { displayed_columns: ['garbage'] } },
        }

        expect(response).to redirect_to(dossiers_path)
        perso = DossiersListPersonnalisation.find_by(user:, procedure:)
        expect(perso&.displayed_columns || []).to eq([])
      end
    end
  end

  describe 'GET #index with personnalisation values' do
    render_views

    let(:user) { create(:user) }
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Titre' }]) }
    let(:column) { procedure.customizable_columns.first }

    before do
      Flipper.enable(:dossiers_list_personnalisation, user)
      create(:dossiers_list_personnalisation, user:, procedure:, displayed_columns: [column])
      sign_in(user)
    end

    def query_count
      count = 0
      callback = -> (*) { count += 1 }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get :index }
      count
    end

    it 'does not issue more queries as more dossiers are added (no N+1)' do
      create_list(:dossier, 6, :en_construction, user:, procedure:, populate_champs: true)
      baseline = query_count

      create_list(:dossier, 6, :en_construction, user:, procedure:, populate_champs: true)
      expect(query_count).to be <= baseline + 3
    end
  end

  describe 'GET #index with personnalisation values – multi-procedure N+1 guard' do
    render_views

    let(:user) { create(:user) }
    let(:procedure1) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Titre' }]) }
    let(:procedure2) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Intitulé' }]) }

    before do
      Flipper.enable(:dossiers_list_personnalisation, user)
      create(:dossiers_list_personnalisation, user:, procedure: procedure1, displayed_columns: [procedure1.customizable_columns.first])
      create(:dossiers_list_personnalisation, user:, procedure: procedure2, displayed_columns: [procedure2.customizable_columns.first])
      sign_in(user)
    end

    def query_count
      count = 0
      callback = -> (*) { count += 1 }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get :index }
      count
    end

    it 'does not issue more queries per dossier with multiple procedures (no N+1 on Column.find)' do
      create_list(:dossier, 3, :en_construction, user:, procedure: procedure1, populate_champs: true)
      create_list(:dossier, 3, :en_construction, user:, procedure: procedure2, populate_champs: true)
      baseline = query_count

      create_list(:dossier, 3, :en_construction, user:, procedure: procedure1, populate_champs: true)
      create_list(:dossier, 3, :en_construction, user:, procedure: procedure2, populate_champs: true)
      expect(query_count).to be <= baseline + 3
    end
  end

  describe 'GET #index with personnalisation values – query cost per personnalised procedure' do
    render_views

    let(:user) { create(:user) }

    before do
      Flipper.enable(:dossiers_list_personnalisation, user)
      sign_in(user)
    end

    def add_personnalised_procedure(libelle)
      procedure = create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: }])
      create(:dossiers_list_personnalisation, user:, procedure:, displayed_columns: [procedure.customizable_columns.first])
      create_list(:dossier, 3, :en_construction, user:, procedure:, populate_champs: true)
    end

    def query_count
      Current.reset
      count = 0
      callback = -> (*) { count += 1 }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get :index }
      count
    end

    it 'adds a bounded number of queries per additional personnalised procedure' do
      add_personnalised_procedure('Titre A')
      add_personnalised_procedure('Titre B')
      query_count
      baseline = query_count

      add_personnalised_procedure('Titre C')

      # 11 mesurées (4 pour le listing de la démarche, 7 pour résoudre les colonnes persistées) + marge
      expect(query_count - baseline).to be <= 13
    end
  end

  describe 'stale personnalisation columns' do
    render_views

    let(:user) { create(:user) }
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Ville' }, { type: :text, libelle: 'Pays' }]) }

    before do
      Flipper.enable(:dossiers_list_personnalisation, user)
      sign_in(user)
    end

    context 'when a persisted column can no longer be resolved' do
      before do
        pays_column = procedure.customizable_columns.find { _1.label == 'Pays' }
        draft_only_tdc = procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'Futur champ')
        draft_only_column = draft_only_tdc.canonical_column(procedure_id: procedure.id)
        create(:dossiers_list_personnalisation, user:, procedure:, displayed_columns: [draft_only_column, pays_column])
        dossiers = create_list(:dossier, 6, :en_construction, user:, procedure:, populate_champs: true)
        dossiers.first.champs.find { _1.stable_id == pays_column.stable_id }.update(value: 'France')
        Current.reset
      end

      it 'renders the dossiers list with the remaining columns' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('France')
      end

      it 'renders the personnalisation screen' do
        get :personnalisation

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the personnalised champ is removed in a later published revision' do
      before do
        ville_column = procedure.customizable_columns.find { _1.label == 'Ville' }
        create(:dossiers_list_personnalisation, user:, procedure:, displayed_columns: [ville_column])
        dossiers = create_list(:dossier, 6, :en_construction, user:, procedure:, populate_champs: true)
        dossiers.first.champs.find { _1.stable_id == ville_column.stable_id }.update(value: 'Nantes')
        procedure.draft_revision.remove_type_de_champ(ville_column.stable_id)
        procedure.publish_revision!(procedure.administrateurs.first)
        Current.reset
      end

      it 'still renders the dossiers list with the removed champ value' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Nantes')
      end

      it 'renders the personnalisation screen' do
        get :personnalisation

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
