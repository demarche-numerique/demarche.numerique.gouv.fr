# frozen_string_literal: true

module SandboxedDecoders
  # Rails names them bare but the sandbox runs an absolute path.
  PREVIEWER_PATHS = { pdftoppm: "/usr/bin/pdftoppm", mutool: "/usr/bin/mutool", ffmpeg: "/usr/bin/ffmpeg" }.freeze

  def self.patch_previewer!
    ActiveStorage::Previewer.prepend(SandboxedPreviewer)
    Rails.application.config.active_storage.paths.merge!(PREVIEWER_PATHS)
  end

  def self.patch_variation!
    ActiveStorage::Variation.prepend(SandboxedVariation)
  end
end

# Previewer lives in the gem's lib/, outside Zeitwerk: required once, patched once at boot.
Rails.application.config.after_initialize { SandboxedDecoders.patch_previewer! if SandboxedCommand::ENABLED }
# Variation lives in the gem's app/models/, which Zeitwerk reloads: patched again each reload.
Rails.application.reloader.to_prepare { SandboxedDecoders.patch_variation! if SandboxedCommand::ENABLED }
