# frozen_string_literal: true

module ApplicationController::ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::InvalidAuthenticityToken do
      render file: Rails.public_path.join('403.html'), layout: false, status: :forbidden
    end

    rescue_from ActionView::MissingTemplate do |exception|
      if request.format.html? || request.format.turbo_stream?
        raise exception
      else
        head :not_acceptable
      end
    end
  end
end
