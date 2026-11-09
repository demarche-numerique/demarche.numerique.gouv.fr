# frozen_string_literal: true

# Devise's `sign_in` in a controller spec writes the Warden key straight into the
# session serializer, firing no callback: no row is opened and the cookie carries
# no id, so the fetch hook rejects the session -- rightly, production always
# writes both. Set the user for real, and let the production hook do the rest.
#
# `login_method:` says how, as application code does: without it, the row is
# one of the sessions opened before methods were recorded.
module SignInOpensASessionRow
  def sign_in(resource, scope: nil, login_method: nil)
    super(resource, scope:)

    return if !resource.is_a?(SessionRegistrableConcern)

    warden.set_user(resource, scope: scope || Devise::Mapping.find_scope!(resource), event: :set_user, login_method:)
  end
end

RSpec.configure do |config|
  # Prepended, not included: this file is loaded before rails_helper includes
  # Devise's helpers, so an include would sit behind them and never run.
  config.prepend SignInOpensASessionRow, type: :controller
  config.prepend SignInOpensASessionRow, type: :view
end
