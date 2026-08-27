# frozen_string_literal: true

# Asked for and impossible is not a state to run in: a machine told to isolate its image
# decoders and unable to do so would decode unprotected, silently, which is the one
# outcome the variable exists to prevent. Same parti pris as Active Storage refusing to
# boot on a libvips too old to disable its unfuzzed loaders.
#
# What the isolation then changes is in config/initializers/sandboxed_decoders.rb.
Rails.application.config.after_initialize do
  SandboxedCommand.ensure_usable! if SandboxedCommand::ENABLED
end
