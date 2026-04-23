# frozen_string_literal: true

module Users
  module DossierStateMapping
    UI_STATES = Dossier.states.values.freeze

    module_function

    def ui_states
      UI_STATES
    end
  end
end
