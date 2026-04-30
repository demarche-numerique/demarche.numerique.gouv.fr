# frozen_string_literal: true

RSpec.describe ApplicationController::ErrorHandling, type: :controller do
  controller(ActionController::Base) do
    include ApplicationController::ErrorHandling

    def invalid_authenticity_token
      raise ActionController::InvalidAuthenticityToken
    end

    def show
      render template: 'nonexistent/template'
    end
  end

  before do
    routes.draw do
      post 'invalid_authenticity_token' => 'anonymous#invalid_authenticity_token'
      get 'show' => 'anonymous#show'
    end
  end

  describe 'handling ActionController::InvalidAuthenticityToken' do
    let(:request_cookies) do
      { 'some_cookie': true }
    end

    before do
      cookies.update(request_cookies)
      allow(controller).to receive(:rand).and_return(0)
    end

    it 'returns a 403 forbidden status' do
      post :invalid_authenticity_token
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'handling unsupported format requests' do
    it 'returns 406 for unsupported formats like zip' do
      get :show, format: :zip
      expect(response).to have_http_status(:not_acceptable)
    end

    it 'raises MissingTemplate for html format' do
      expect { get :show, format: :html }.to raise_error(ActionView::MissingTemplate)
    end

    it 'raises MissingTemplate for turbo_stream format' do
      expect { get :show, format: :turbo_stream }.to raise_error(ActionView::MissingTemplate)
    end
  end
end
