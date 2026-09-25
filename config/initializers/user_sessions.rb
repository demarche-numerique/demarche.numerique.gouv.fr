# frozen_string_literal: true

# One block per Warden event, each handing over to the concern: the order the
# steps run in is load-bearing, so it belongs inside one method rather than in
# the order of the blocks in this file.
Warden::Manager.after_set_user do |record, warden, options|
  SessionRegistrableConcern.after_set_user(record, warden, options)
end

Warden::Manager.before_logout do |record, warden, options|
  SessionRegistrableConcern.before_logout(record, warden, options)
end
