# frozen_string_literal: true

describe RechercheController, type: :controller do
  let(:procedure) {
    create(:procedure, :published,
                       :for_individual,
                       types_de_champ_public: [{ type: :text }, { type: :text }],
                       types_de_champ_private: [{ type: :text }, { type: :text }])
  }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }
  let(:instructeur) { create(:instructeur) }

  let(:dossier_with_expert) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }
  let(:avis) { create(:avis, dossier: dossier_with_expert) }

  let(:user) { instructeur.user }

  before { instructeur.assign_to_procedure(dossier.procedure) }

  describe 'GET #index' do
    before { sign_in(user) }

    subject { get :index, params: { q: query } }

    describe 'by id' do
      context 'when instructeur own the dossier' do
        let(:query) { dossier.id }

        it 'returns the expected dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to match_array([dossier])
        end
      end

      context 'when expert own the dossier' do
        let(:user) { avis.experts_procedure.expert.user }
        let(:query) { dossier_with_expert.id }

        it 'returns the expected dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to match_array([dossier_with_expert])
        end
      end

      context 'when instructeur do not own the dossier' do
        let(:dossier2) { create(:dossier, :en_construction) }
        let(:query) { dossier2.id }

        it 'does not return the dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to be_empty
          expect(assigns(:dossier_not_in_instructor_group)).to eq(nil)
        end
      end

      context 'when dossier is brouillon without groupe instructeur' do
        let(:dossier2) { create(:dossier, :brouillon, procedure: procedure) }
        let(:query) { dossier2.id }
        before { dossier2.update(groupe_instructeur_id: nil) }

        it 'does not return the dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to eq([])
          expect(assigns(:dossier_not_in_instructor_group)).to eq(nil)
        end
      end

      context 'when instructeur is attached to the procedure but is not in the instructor group of the dossier' do
        let!(:gi_p1_1) { GroupeInstructeur.create(label: 'groupe 1', procedure: procedure) }
        let!(:gi_p1_2) { GroupeInstructeur.create(label: 'groupe 2', procedure: procedure) }
        let!(:dossier3) { create(:dossier, :accepte, :with_individual, procedure: procedure, groupe_instructeur: gi_p1_2) }

        before { gi_p1_1.instructeurs << instructeur }

        let(:query) { dossier3.id }

        it 'does not return the dossier but it returns a message' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to eq(nil)
          expect(assigns(:dossier_not_in_instructor_group)).to eq(dossier3)
        end

        context 'rendered response' do
          render_views

          it 'does not disclose the label of the other groupe instructeur' do
            subject
            expect(response.body).not_to include(gi_p1_2.label)
          end
        end
      end

      context 'when dossier is deleted' do
        let!(:deleted_dossier) { DeletedDossier.create_from_dossier(dossier, DeletedDossier.reasons.fetch(:user_request)) }
        let(:query) { deleted_dossier.dossier_id }

        it 'does not return the dossier but it returns a message' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to eq(nil)
          expect(assigns(:deleted_dossier)).to eq(deleted_dossier)
        end
      end

      context 'when dossier is hidden by administration' do
        let!(:hidden_dossier) { create(:dossier, :accepte, :hidden_by_administration, :with_individual, procedure: procedure) }
        let(:query) { hidden_dossier.id }

        it 'does not return the dossier but it returns a message' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to eq(nil)
          expect(assigns(:hidden_dossier)).to eq(hidden_dossier)
        end
      end

      context 'with an id out of range' do
        let(:query) { 123456789876543234567 }

        it 'does not return the dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to be_empty
        end
      end
    end

    describe 'by champs' do
      before do
        dossier.project_champs_public[0].value = "Name of district A"
        dossier.project_champs_public[1].value = "75000"
        dossier.save!

        dossier_with_expert.project_champs_public[0].value = "Name of district B"
        dossier_with_expert.save!

        perform_enqueued_jobs(only: DossierIndexSearchTermsJob)
      end

      context 'when search is a string' do
        let(:query) { 'district A' }

        it 'returns the expected dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to match_array([dossier])
        end
      end

      context 'when search is a string of number' do
        let(:query) { '75000  ' }

        it 'returns the expected dossier' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to match_array([dossier])
        end
      end

      context 'when dossier has notification' do
        let(:query) { 'district A' }
        let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_modifie) }

        it 'assigns notification' do
          subject
          expect(assigns(:notifications)).to eq({ dossier.id => [notification] })
        end
      end

      context 'as an expert' do
        let(:user) { avis.experts_procedure.expert.user }
        let(:query) { 'district' }

        it 'returns only the dossier available to the expert' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to match_array([dossier_with_expert])
        end
      end
    end

    describe 'by private annotations' do
      let(:query) { 'invalid' }

      before do
        dossier_with_expert.project_champs_private[1].value = "Dossier B is invalid"
        dossier_with_expert.save!

        perform_enqueued_jobs(only: DossierIndexSearchTermsJob)
      end

      it 'returns the expected dossier' do
        is_expected.to have_http_status(200)
        expect(assigns(:projected_dossiers)).to match_array([dossier_with_expert])
      end

      context 'as an expert' do
        let(:user) { avis.experts_procedure.expert.user }

        it 'does not allow experts to search in private annotations' do
          is_expected.to have_http_status(200)
          expect(assigns(:projected_dossiers)).to be_empty
        end
      end
    end

    context 'with no query param it does not crash' do
      subject { get :index, params: {} }

      it 'returns 0 dossier' do
        is_expected.to have_http_status(200)
        expect(assigns(:projected_dossiers)).to be_empty
      end
    end

    context 'nav bar profile in user context' do
      subject { get(:index, params: {}).body }
      render_views

      it 'define user nav' do
        expect(subject).to include "Mes dossiers"
        expect(subject).to include "usager"
      end
    end

    context 'nav bar profile in instructeur context' do
      subject { get(:index, params: { context: :instructeur }).body }
      render_views

      it 'define instructeur nav' do
        expect(subject).to include "Démarches"
        expect(subject).to include "instructeur"
        expect(subject).not_to include "Mes dossiers"
      end
    end

    context 'nav bar profile in expert context' do
      before { user.create_expert }
      subject { get(:index, params: { context: :expert }).body }
      render_views

      it 'define expert nav' do
        expect(subject).to include "Avis"
        expect(subject).to include "expert"
        expect(subject).not_to include "Mes dossiers"
      end
    end
  end
end
