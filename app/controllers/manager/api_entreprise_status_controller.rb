# frozen_string_literal: true

module Manager
  class APIEntrepriseStatusController < Manager::ApplicationController
    def show
      @status = APIEntreprise::Status.new
    end
  end
end
