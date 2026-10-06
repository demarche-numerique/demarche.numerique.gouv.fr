# frozen_string_literal: true

RSpec.describe ErrorsController, type: :controller do
  render_views

  describe 'GET #internal_server_error' do
    context 'when the database is unreachable' do
      before do
        allow(Banner).to receive(:find_by).and_raise(ActiveRecord::DatabaseConnectionError.hostname_error('db'))
        allow(Sentry).to receive(:capture_exception)
      end

      it 'still renders the error page' do
        get :internal_server_error

        expect(response).to have_http_status(:internal_server_error)
        expect(response).to render_template(:internal_server_error)
        expect(Sentry).not_to have_received(:capture_exception)
      end

      context 'with a super admin session' do
        before do
          sign_in(create(:super_admin), scope: :super_admin)
          allow(SuperAdmin).to receive(:serialize_from_session).and_raise(ActiveRecord::DatabaseConnectionError.hostname_error('db'))
        end

        it 'still renders the error page' do
          get :internal_server_error

          expect(response).to render_template(:internal_server_error)
        end
      end
    end
  end

  describe 'GET #show' do
    # rspec can't easily manage the exceptions_app for a real route,
    # just verify the action renders correctly
    let(:status_code) { 426 }
    let(:status_message) { 'Upgrade Required' }

    context 'HTML format' do
      subject do
        get :show, params: { status: status_code }, format: :html
      end

      it 'correctly handles and responds with an HTML response' do
        subject
        expect(response).to have_http_status(status_code)
        expect(response.body).to include(status_message)
      end
    end

    context 'JSON format' do
      subject do
        get :show, params: { status: status_code }, format: :json
      end

      it 'correctly handles and responds with a JSON response' do
        subject
        expect(response).to have_http_status(status_code)
        json_response = response.parsed_body

        expect(json_response['status']).to eq(status_code)
        expect(json_response['name']).to eq(status_message)
      end
    end
  end

  describe 'specific actions shortcuts' do
    it 'renders 404' do
      get :not_found
      expect(response).to have_http_status(:not_found)
    end

    it 'renders 422' do
      get :unprocessable_entity
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET #unprocessable_entity' do
    context 'when user is not signed in' do
      it 'renders the generic template' do
        get :unprocessable_entity, format: :html

        expect(response).to render_template('errors/unprocessable_entity')
      end
    end

    context 'when user is signed' do
      before { sign_in(create(:user)) }
      context 'with HTML referer' do
        before do
          request.env['HTTP_REFERER'] = 'http://test.host/dossiers/123'
        end

        it 'redirects to the referer with csrf_retry flag' do
          get :unprocessable_entity, format: :html

          expect(response).to redirect_to('http://test.host/dossiers/123?csrf_retry=1')
        end
      end

      context 'with referer already flagged' do
        before do
          request.env['HTTP_REFERER'] = 'http://test.host/dossiers/123?csrf_retry=1'
        end

        it 'falls back to the generic rendering' do
          get :unprocessable_entity, format: :html

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to render_template('errors/unprocessable_entity')
        end
      end

      context 'without InvalidAuthenticityToken' do
        it 'renders the generic template' do
          get :unprocessable_entity, format: :html

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to render_template('errors/unprocessable_entity')
        end
      end
    end
  end

  describe 'csrf retry flash' do
    it 'shows a message when csrf_retry parameter is present' do
      get :show, params: { status: 404, csrf_retry: '1' }, format: :html

      expect(flash.now[:alert]).to eq(I18n.t('errors.csrf_retry.message'))
    end
  end
end
