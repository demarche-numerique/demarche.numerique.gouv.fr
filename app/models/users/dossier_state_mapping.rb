# frozen_string_literal: true

module Users
  module DossierStateMapping
    UI_STATES = %w[brouillon depose en_instruction accepte refuse sans_suite].freeze
    UI_TO_MODEL = { 'depose' => 'en_construction' }.freeze

    module_function

    def ui_states
      UI_STATES
    end

    def model_state_for(ui_state)
      return nil unless UI_STATES.include?(ui_state)
      UI_TO_MODEL.fetch(ui_state, ui_state)
    end
  end
end
