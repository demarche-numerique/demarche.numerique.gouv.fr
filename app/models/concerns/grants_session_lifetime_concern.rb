# frozen_string_literal: true

# Granting a role must not leave sessions already open living under the deadline
# of the role the account had before.
module GrantsSessionLifetimeConcern
  extend ActiveSupport::Concern

  included do
    # The lifetime read from the role being created, not from the owner: inside
    # the `after_create` the owner still answers nil for it, and asking would
    # cost a re-`find` under User's eager load on every promotion.
    after_create -> { user&.tighten_sessions!(User::SESSION_MAX_LIFETIMES.fetch(model_name.singular.to_sym)) }
  end
end
