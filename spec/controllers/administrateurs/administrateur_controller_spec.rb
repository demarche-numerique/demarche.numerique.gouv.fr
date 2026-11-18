# frozen_string_literal: true

describe Administrateurs::AdministrateurController, type: :controller do
  describe 'before actions: authenticate_administrateur!' do
    it 'is present' do
      before_actions = Administrateurs::AdministrateurController
        ._process_action_callbacks
        .filter { |process_action_callbacks| process_action_callbacks.kind == :before }
        .map(&:filter)

      expect(before_actions).to include(:authenticate_administrateur!)
    end
  end

  describe 'alerts about published procedures with an incomplete service' do
    controller(Administrateurs::AdministrateurController) do
      def index = head(:ok)
    end

    let(:administrateur) { create(:administrateur) }

    before do
      create(:procedure, :published, administrateur:, service: create(:service).tap { it.update_column(:siret, nil) })
      create(:procedure, :published, administrateur:).tap { it.update_column(:service_id, nil) }
      sign_in(administrateur.user)
    end

    it 'shows them on an HTML page' do
      get :index

      expect(flash.now[:alert]).to include(I18n.t('shared.procedures.no_siret'))
    end

    it 'leaves them out of a turbo stream response, which would focus the flash and scroll the page to the top' do
      get :index, format: :turbo_stream

      expect(flash.now[:alert]).to be_nil
    end
  end
end
