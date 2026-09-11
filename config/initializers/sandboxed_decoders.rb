# frozen_string_literal: true

module SandboxedDecoders
  # Rails names them bare but the sandbox runs an absolute path. The arguments are the
  # ones Active Storage probes each binary with to decide whether to offer its previewer.
  PREVIEWERS = {
    pdftoppm: ["/usr/bin/pdftoppm", "-v"],
    mutool: ["/usr/bin/mutool", "-v"],
    ffmpeg: ["/usr/bin/ffmpeg", "-version"],
  }.freeze

  def self.patch_previewer!
    PREVIEWERS.each_value { ensure_runs_in_sandbox!(it) }

    ActiveStorage::Previewer.prepend(SandboxedPreviewer)
    Rails.application.config.active_storage.paths.merge!(PREVIEWERS.transform_values(&:first))
  end

  # Active Storage asks the host whether to offer a previewer; the sandbox runs it. Absent
  # is fine, installed and unable to start there would be offered and fail on every upload.
  def self.ensure_runs_in_sandbox!(argv)
    return if !File.exist?(argv.first)

    _, error, status = SandboxedCommand.run(argv)
    raise "#{argv.first} will not run in the sandbox: #{error.strip}" if !status.success?
  end

  def self.patch_variation!
    ActiveStorage::Variation.prepend(SandboxedVariation)
  end
end

# Previewer lives in the gem's lib/, outside Zeitwerk: required once, patched once at boot.
Rails.application.config.after_initialize { SandboxedDecoders.patch_previewer! if SandboxedCommand::ENABLED }
# Variation lives in the gem's app/models/, which Zeitwerk reloads: patched again each reload.
Rails.application.reloader.to_prepare { SandboxedDecoders.patch_variation! if SandboxedCommand::ENABLED }
