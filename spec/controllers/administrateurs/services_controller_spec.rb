# frozen_string_literal: true

describe Administrateurs::ServicesController, type: :controller do
  let(:admin) { administrateurs.default }
  let(:procedure) { create(:procedure, administrateur: admin) }

  describe '#new' do
    let(:procedure) { create(:procedure, administrateur: admin) }

    before do
      sign_in(admin.user)
    end

    subject { get :new, params: { procedure_id: procedure.id } }

    context 'when admin has a SIRET from ProConnect' do
      let(:siret) { "20004021000060" }

      before do
        create(:pro_connect_information, siret:, user: admin.instructeur.user)
      end

      it 'prefills the SIRET and fetches service information' do
        VCR.use_cassette("annuaire_service_public_success_#{siret}") do
          subject
          expect(assigns[:service].siret).to eq(siret)
          expect(assigns[:service].nom).to eq("Communauté de communes - Lacs et Gorges du Verdon")
          expect(assigns[:service].adresse).to eq("242 avenue Albert-1er 83630 Aups")
          expect(assigns[:prefilled]).to eq(true)
        end
      end
    end

    context 'when admin has no SIRET from ProConnect' do
      it 'does not prefill the SIRET' do
        subject
        expect(assigns[:service].siret).to be_nil
        expect(assigns[:prefilled]).to be_nil
      end
    end
  end

  describe '#prefill' do
    before do
      sign_in(admin.user)
    end

    subject { post :prefill, params:, xhr: true }

    context 'when prefilling a new service from a SIRET' do
      let(:params) do
        {
          procedure_id: procedure.id,
          service: {
            siret: "20004021000060",
          },
        }
      end

      it "prefill from annuaire public" do
        VCR.use_cassette('annuaire_service_public_success_20004021000060') do
          subject
          expect(response.body).to include('turbo-stream')
          expect(assigns[:service].nom).to eq("Communauté de communes - Lacs et Gorges du Verdon")
          expect(assigns[:service].adresse).to eq("242 avenue Albert-1er 83630 Aups")
        end
      end
    end

    context 'when prefilling an existing service from a SIRET' do
      let!(:service) { create(:service, siret: "35600082800018", administrateur: admin) }

      let(:params) do
        {
          id: service.id,
          procedure_id: procedure.id,
          service: {
            siret: "20004021000060",
          },
        }
      end

      it 'prefills the existing service' do
        VCR.use_cassette('annuaire_service_public_success_20004021000060') do
          subject

          expect(response.body).to include('turbo-stream')
          expect(assigns[:service]).to eq(service)
          expect(assigns[:service]).not_to be_new_record
          expect(assigns[:service].siret).to eq("20004021000060")
          expect(assigns[:service].nom).to eq("Communauté de communes - Lacs et Gorges du Verdon")
          expect(assigns[:service].adresse).to eq("242 avenue Albert-1er 83630 Aups")
        end
      end
    end

    context 'when attempting to prefilling from invalid SIRET' do
      let(:params) do
        {
          procedure_id: procedure.id,
          service: {
            siret: "20004021000000",
          },
        }
      end

      it "render an error" do
        subject
        expect(response.body).to include('turbo-stream')
        expect(assigns[:service].nom).to be_nil
        expect(assigns[:service].errors.key?(:siret)).to be_present
      end
    end

    context 'when attempting to prefilling from not service public SIRET' do
      let(:params) do
        {
          procedure_id: procedure.id,
          service: {
            siret: "41816609600051",
          },
        }
      end

      it "render partial information" do
        VCR.use_cassette('annuaire_service_public_success_41816609600051') do
          subject
          expect(response.body).to include('turbo-stream')
          expect(assigns[:service].nom).to eq("OCTO-TECHNOLOGY")
          expect(assigns[:service].horaires).to be_nil
          expect(assigns[:service].errors.key?(:siret)).not_to be_present
        end
      end
    end
  end

  describe '#create' do
    before do
      sign_in(admin.user)
    end

    subject { post :create, params: }

    context 'when submitting a new service' do
      let(:params) do
        {
          service: {
            nom: 'super service',
            organisme: 'organisme',
            type_organisme: 'association',
            email: 'email@toto.com',
            telephone: '1234',
            horaires: 'horaires',
            adresse: 'adresse',
            siret: "35600011719156",
          },
          procedure_id: procedure.id,
        }
      end

      it do
        subject
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq('super service créé')
        expect(Service.last.nom).to eq('super service')
        expect(Service.last.organisme).to eq('organisme')
        expect(Service.last.type_organisme).to eq(Service.type_organismes.fetch(:association))
        expect(Service.last.email).to eq('email@toto.com')
        expect(Service.last.telephone).to eq('1234')
        expect(Service.last.horaires).to eq('horaires')
        expect(Service.last.adresse).to eq('adresse')
        expect(Service.last.siret).to eq('35600011719156')
        expect(APIEntreprise::ServiceJob).to have_been_enqueued.with(Service.last.id)

        expect(response).to redirect_to(admin_services_path(procedure_id: procedure.id))
      end
    end

    context 'when submitting an invalid service' do
      let(:params) { { service: { nom: 'super service' }, procedure_id: procedure.id } }

      it do
        subject
        expect(flash.alert).not_to be_nil
        expect(response).to render_template(:new)
        expect(assigns(:service).nom).to eq('super service')
      end
    end
  end

  describe '#edit' do
    render_views

    let!(:service) { create(:service, administrateur: admin) }
    let!(:procedure) { create(:procedure, administrateur: admin, service: service) }

    before { sign_in(admin.user) }

    subject { get :edit, params: { id: service.id, procedure_id: procedure.id } }

    context 'when the service is used only by the current procedure' do
      it 'assigns no other procedures and does not render the warning' do
        subject
        expect(assigns(:other_procedures)).to be_empty
        expect(response.body).not_to include("impactera également les démarches suivantes")
      end
    end

    context 'when the service is used by other procedures' do
      let!(:other_published) { create(:procedure, :published, administrateur: admin, service: service, libelle: 'Démarche partagée') }
      let!(:other_draft) { create(:procedure, administrateur: admin, service: service) }
      let!(:other_closed) { create(:procedure, :closed, administrateur: admin, service: service) }

      it 'assigns all other procedures regardless of state and lists them in the warning' do
        subject
        expect(assigns(:other_procedures)).to contain_exactly(other_published, other_draft, other_closed)
        expect(response.body).to include("impactera également les démarches suivantes")
        expect(response.body).to include("Démarche partagée - n°#{other_published.id}")
        expect(response.body).to include("n°#{other_draft.id}")
        expect(response.body).to include("n°#{other_closed.id}")
      end
    end

    context 'when the service is shared with a co-administrateur' do
      let(:other_admin) { create(:administrateur) }
      let!(:service) { create(:service, administrateur: other_admin) }
      let!(:procedure) { create(:procedure, administrateurs: [other_admin, admin], service: service) }
      let!(:other_published) { create(:procedure, :published, administrateur: other_admin, service: service) }

      it 'allows the co-administrateur to access the edit form and warns about other procedures' do
        subject
        expect(response).to have_http_status(:ok)
        expect(assigns(:service)).to eq(service)
        expect(assigns(:other_procedures)).to contain_exactly(other_published)
      end
    end
  end

  describe '#update' do
    let!(:service) { create(:service, administrateur: admin) }
    let(:service_params) { { nom: 'nom', type_organisme: Service.type_organismes.fetch(:association), siret: "13002526500013" } }

    before do
      sign_in(admin.user)
      params = {
        id: service.id,
        service: service_params,
        procedure_id: procedure.id,
      }
      patch :update, params: params
    end

    context 'when updating a service' do
      it do
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq('nom modifié')
        expect(Service.last.nom).to eq('nom')
        expect(Service.last.type_organisme).to eq(Service.type_organismes.fetch(:association))
        expect(response).to redirect_to(admin_services_path(procedure_id: procedure.id))
        expect(APIEntreprise::ServiceJob).to have_been_enqueued.with(service.id)
      end
    end

    context 'when updating a service with invalid data' do
      render_views

      let(:service_params) { { nom: '', type_organisme: Service.type_organismes.fetch(:association) } }

      it do
        expect(flash.alert).not_to be_nil
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:edit)
      end
    end

    context 'when a co-administrateur updates a shared service' do
      let(:other_admin) { create(:administrateur) }
      let!(:service) { create(:service, administrateur: other_admin, nom: 'Original') }
      let!(:procedure) { create(:procedure, administrateurs: [other_admin, admin], service: service) }

      it 'updates the service' do
        expect(flash.alert).to be_nil
        expect(service.reload.nom).to eq('nom')
      end
    end
  end

  describe '#add_to_procedure' do
    let!(:procedure) { create(:procedure, administrateur: admin) }
    let!(:service) { create(:service, administrateur: admin) }

    def post_add_to_procedure
      sign_in(admin.user)
      params = {
        procedure: {
          id: procedure.id,
          service_id: service.id,
        },
      }
      patch :add_to_procedure, params: params
      procedure.reload
    end

    context 'when adding a service to a procedure' do
      before { post_add_to_procedure }

      it do
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq("Service affecté : #{service.nom}")
        expect(procedure.service_id).to eq(service.id)
        expect(response).to redirect_to(admin_procedure_path(procedure.id))
      end
    end

    context 'when stealing a service to add it to a procedure' do
      let!(:service) { create(:service) }

      it { expect { post_add_to_procedure }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe '#destroy' do
    let!(:service) { create(:service, administrateur: admin) }

    context 'when a service has no related procedure' do
      before do
        sign_in(admin.user)
        delete :destroy, params: { id: service.id, procedure_id: procedure.id }
      end

      it do
        expect { service.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq("#{service.nom} est supprimé")
        expect(response).to redirect_to(admin_services_path(procedure_id: procedure.id))
      end
    end

    context 'when a service still has some related procedures' do
      let!(:procedure) { create(:procedure, service: service) }

      before do
        sign_in(admin.user)
        delete :destroy, params: { id: service.id, procedure_id: procedure.id }
      end

      it do
        expect(service.reload).not_to be_nil
        expect(flash.alert).to eq("La démarche #{procedure.libelle} utilise encore le service #{service.nom}. Veuillez l’affecter à un autre service avant de pouvoir le supprimer")
        expect(flash.notice).to be_nil
        expect(response).to redirect_to(admin_services_path(procedure_id: procedure.id))
      end
    end

    context "when a service has some related discarded procedures" do
      let!(:procedure) { create(:procedure, :discarded, service: service) }

      before do
        sign_in(admin.user)
        delete :destroy, params: { id: service.id, procedure_id: procedure.id }
      end

      it do
        expect { service.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq("#{service.nom} est supprimé")
        expect(procedure.reload.service_id).to be_nil
      end
    end

    context 'when a co-administrateur tries to destroy a shared service owned by another admin' do
      let(:other_admin) { create(:administrateur) }
      let!(:service) { create(:service, administrateur: other_admin) }
      let!(:procedure) { create(:procedure, administrateurs: [other_admin, admin]) }

      before { sign_in(admin.user) }

      it 'forbids the destruction even if no procedure references the service' do
        expect { delete :destroy, params: { id: service.id, procedure_id: procedure.id } }
          .to raise_error(ActiveRecord::RecordNotFound)
        expect { service.reload }.not_to raise_error
      end
    end
  end

  describe "#index" do
    let(:admin) { administrateurs.default }

    before do
      sign_in(admin.user)
    end

    context 'when admin has service without siret' do
      let(:service) { create(:service) }
      let(:procedure) { create(:procedure, :published, service: service, administrateur: admin) }

      it 'display alert when admin has service without siret' do
        service.siret = nil
        service.save(validate: false)
        get :index, params: { procedure_id: procedure.id }
        expect(flash.alert.first).to eq "Vous n’avez pas renseigné le siret du service pour certaines de vos démarches. Merci de les modifier."
        expect(flash.alert.last).to include(procedure.libelle)
      end
    end

    context 'when admin has procedure without service' do
      let(:procedure) { create(:procedure, :published, service: nil, administrateur: admin) }

      it 'display alert' do
        get :index, params: { procedure_id: procedure.id }
        expect(procedure.service).to be nil
        expect(flash.alert.first).to eq "Certaines de vos démarches n’ont pas de service associé."
        expect(flash.alert.last).to include "démarche #{procedure.id}"
      end
    end

    context 'when listing services on a procedure shared with a co-administrateur' do
      render_views

      let(:other_admin) { create(:administrateur) }
      let!(:foreign_service) { create(:service, administrateur: other_admin) }
      let!(:procedure) { create(:procedure, administrateurs: [other_admin, admin], service: foreign_service) }

      it 'disables the destroy button for services not owned by the current administrateur' do
        get :index, params: { procedure_id: procedure.id }

        destroy_form = response.parsed_body
          .css("form[action='#{admin_service_path(foreign_service, procedure_id: procedure.id)}'][method='post']")
        expect(destroy_form.css("button[disabled]")).not_to be_empty
      end
    end
  end
end
