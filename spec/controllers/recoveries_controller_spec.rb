# frozen_string_literal: true

describe RecoveriesController, type: :controller do
  include Dry::Monads[:result]

  describe 'GET #nature' do
    render_views

    subject { get :nature }

    it do
      subject
      expect(response.body).to have_css('h2', text: 'Nature des dossiers')
      expect(response.body).to have_field('des dossiers concernant une collectivité territoriale', type: 'radio')
      expect(response.body).to have_field('autre', type: 'radio', exact: true)
      expect(response.body).to have_button('Continuer', disabled: true)
    end
  end

  describe 'POST #post_nature' do
    subject { post :post_nature, params: { nature: nature } }

    context 'when nature is collectivite' do
      let(:nature) { 'collectivite' }

      it { is_expected.to redirect_to(identification_recovery_path) }
    end

    context 'when nature is not collectivite' do
      let(:nature) { 'other' }

      it { is_expected.to redirect_to(support_recovery_path(error: :other_nature)) }
    end
  end

  describe 'Get #support' do
    render_views

    subject { get :support, params: { error: } }

    let(:error) { nil }

    it { is_expected.to have_http_status(:success) }

    context 'when the nature is not supported' do
      let(:error) { 'other_nature' }

      it do
        subject
        expect(response.body).to have_text('Votre situation nécessite un traitement particulier.')
        expect(response.body).to have_link('Contactez le support', href: /\Amailto:/)
      end
    end

    context 'when pro connect must be used' do
      let(:error) { 'must_use_pro_connect' }

      it { expect(subject.body).to have_text('Vous devez utiliser le portail ProConnect pour récupérer vos dossiers.', normalize_ws: true) }
    end

    context 'when there is no dossier' do
      let(:error) { 'no_dossier' }

      it do
        subject
        expect(response.body).to have_text('que vous avez renseignée nʼa pas de dossier concernant votre organisation.', normalize_ws: true)
        expect(response.body).to have_link('Essayer avec une autre adresse électronique', href: identification_recovery_path)
        expect(response.body).to have_link('Contactez le support', href: /\Amailto:/)
      end
    end
  end

  describe 'ensure_pro_connect_is_used' do
    subject { post :selection }

    before do
      allow(controller).to receive(:ensure_collectivite_territoriale).and_return(true)
      allow(controller).to receive(:selection).and_return(true)
    end

    context 'when pro connect is used' do
      let(:instructeur) { create(:instructeur, :with_pro_connect_information) }

      before do
        allow(controller).to receive(:current_instructeur).and_return(instructeur)
      end

      it { is_expected.to have_http_status(:success) }
    end

    context 'when pro connect is not used' do
      it { is_expected.to redirect_to(support_recovery_path(error: :must_use_pro_connect)) }
    end
  end

  describe 'ensure_collectivite_territoriale' do
    subject { post :selection }

    before do
      allow(controller).to receive(:ensure_pro_connect_is_used).and_return(true)
      allow(controller).to receive(:siret).and_return('123')
      allow(controller).to receive(:selection).and_return(true)
    end

    context 'when collectivite territoriale' do
      before do
        allow(APIRechercheEntreprisesService).to receive(:collectivite_territoriale?).and_return(true)
      end

      it { is_expected.to have_http_status(:success) }
    end

    context 'when not collectivite territoriale' do
      before do
        allow(APIRechercheEntreprisesService).to receive(:collectivite_territoriale?).and_return(false)
      end

      it { is_expected.to redirect_to(support_recovery_path(error: 'not_collectivite_territoriale')) }
    end
  end

  context 'when the current instructeur used pro connect and works for a collectivite territoriale' do
    let(:instructeur) { create(:instructeur, :with_pro_connect_information) }
    let(:api_recherche_result) do
      { nom_complet: 'name', complements: { collectivite_territoriale: { is: :present } } }
    end

    before do
      allow(controller).to receive(:current_instructeur).and_return(instructeur)
      allow_any_instance_of(APIRechercheEntreprisesService).to receive(:call)
        .and_return(Success(api_recherche_result))
    end

    describe 'GET #identification' do
      render_views

      subject { get :identification }

      it do
        subject
        expect(response.body).to have_css('h2', text: 'Identification du propriétaire des dossiers')
        expect(response.body).to have_css('p', text: 'Votre organisation est « name » identifiée par le SIRET 12345678901234', normalize_ws: true)
        expect(response.body).to have_field('Adresse électronique du propriétaire des dossiers', type: 'email')
        expect(response.body).to have_button('Continuer')
      end
    end

    describe 'POST #post_identification' do
      subject { post :post_identification, params: { previous_email: 'email@a.com' } }

      it do
        response = subject
        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with(selection_recovery_url)
      end
    end

    describe 'GET #selection' do
      subject { get :selection }

      context 'when there are no recoverable procedures' do
        before do
          allow(RecoveryService).to receive(:recoverable_procedures).and_return([])
        end

        it { is_expected.to redirect_to(support_recovery_path(error: :no_dossier)) }
      end

      context 'when there are recoverable procedures' do
        render_views

        let(:recoverable_procedures) { [{ procedure_id: 1, libelle: 'libelle', count: 2 }] }

        before do
          allow(RecoveryService).to receive(:recoverable_procedures).and_return(recoverable_procedures)
        end

        it do
          subject
          expect(response.body).to have_css('h2', text: 'Sélection des démarches')
          expect(response.body).to have_css('legend', text: 'Sélectionner les démarches que vous souhaitez récupérer.')
          expect(response.body).to have_field('libelle', type: 'checkbox', with: '1')
          expect(response.body).to have_button('Continuer', disabled: true)
        end
      end
    end

    describe 'POST #post_selection' do
      subject { post :post_selection, params: { procedure_ids: [1] } }

      before { expect(RecoveryService).to receive(:recover_procedure!) }

      it { is_expected.to redirect_to(terminee_recovery_path) }
    end
  end
end
