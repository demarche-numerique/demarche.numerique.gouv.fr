# frozen_string_literal: true

module Users
  module DossierStateMapping
    UI_STATES = [
      Dossier.states.fetch(:brouillon),
      Dossier.states.fetch(:en_construction),
      Dossier.states.fetch(:en_instruction),
      Dossier.states.fetch(:accepte),
      Dossier.states.fetch(:refuse),
      Dossier.states.fetch(:sans_suite),
    ].freeze

    USER_FACING_LABEL_KEYS = { 'en_construction' => 'depose' }.freeze

    module_function

    def ui_states
      UI_STATES
    end

    def state_label(state)
      key = USER_FACING_LABEL_KEYS.fetch(state, state)
      I18n.t(key, scope: 'activerecord.attributes.dossier/state')
    end
  end
end
