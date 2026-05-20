# frozen_string_literal: true

module Users
  module DossierStateMapping
    UI_STATES = Dossier.states.values.freeze

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
