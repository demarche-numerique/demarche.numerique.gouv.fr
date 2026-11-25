# frozen_string_literal: true

class AdministrateurCreationRequestJob < ApplicationJob
  def perform(creation_request)
    creation_request.create_accounts!
  end
end
