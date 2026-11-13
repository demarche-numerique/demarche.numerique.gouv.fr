# frozen_string_literal: true

# Devise's `sign_in` in a controller spec writes the Warden key straight into the
# session serializer, firing no callback: no row is opened and the cookie carries
# no id, so the fetch hook rejects the session -- rightly, production always
# writes both. Set the user for real, and let the production hook do the rest.
#
# `login_method:` says how, as application code does: without it, the row is
# one of the sessions opened before methods were recorded.
module SignInOpensASessionRow
  def sign_in(resource, scope: nil, login_method: nil, france_connect_information: nil)
    super(resource, scope:)

    return if !resource.is_a?(SessionRegistrableConcern)

    scope ||= Devise::Mapping.find_scope!(resource)
    warden.set_user(resource, scope:, event: :set_user, login_method:, france_connect_information:)
  end

  # Production gives each request a new Warden proxy, which reads the user back
  # from the session and fires the fetch hook that fills `Current` inside the
  # executor wrapping the request. A controller spec keeps the proxy, and the
  # controller its `current_user`, across the example: fire the fetch hook again,
  # inside the executor, on the very users the example may have set expectations on.
  private def wrap_execution
    super do
      warden.instance_variable_get(:@users).compact.each do |scope, user|
        warden.set_user(user, scope:, event: :fetch)
      end
      yield
    end
  end
end

RSpec.configure do |config|
  # Prepended, not included: this file is loaded before rails_helper includes
  # Devise's helpers, so an include would sit behind them and never run.
  config.prepend SignInOpensASessionRow, type: :controller
  config.prepend SignInOpensASessionRow, type: :view
end
