# frozen_string_literal: true

Warden::Manager.after_set_user do |record, warden, options|
  SessionRegistrableConcern.after_set_user(record, warden, options)
end

Warden::Manager.before_logout do |record, warden, options|
  SessionRegistrableConcern.before_logout(record, warden, options)
end
