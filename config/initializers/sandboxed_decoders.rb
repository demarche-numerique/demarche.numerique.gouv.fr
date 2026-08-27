# frozen_string_literal: true

# Where the isolation is asked for, Active Storage decodes through the sandbox: previews
# through SandboxedPreviewer, variants through SandboxedVariation. Without it, nothing is
# grafted and Active Storage is left exactly as it is.
module SandboxedDecoders
  # Rails names them bare but the sandbox runs an absolute path.
  PREVIEWER_PATHS = { pdftoppm: "/usr/bin/pdftoppm", mutool: "/usr/bin/mutool", ffmpeg: "/usr/bin/ffmpeg" }.freeze

  def self.graft!
    return if !SandboxedCommand::ENABLED

    ActiveStorage::Previewer.prepend(SandboxedPreviewer)
    ActiveStorage::Variation.prepend(SandboxedVariation)
    Rails.application.config.active_storage.paths.merge!(PREVIEWER_PATHS)
  end
end

# Inside to_prepare because these constants are autoloaded, and an initializer body runs
# before the autoloader is ready to answer.
Rails.application.reloader.to_prepare { SandboxedDecoders.graft! }
