# frozen_string_literal: true

module Users
  module DossierStateMapping
    UI_STATES = %w[brouillon depose en_instruction accepte refuse sans_suite].freeze

    module_function

    def model_state_for(ui_state)
      return nil unless UI_STATES.include?(ui_state)
      ui_state == 'depose' ? 'en_construction' : ui_state
    end
  end
end
