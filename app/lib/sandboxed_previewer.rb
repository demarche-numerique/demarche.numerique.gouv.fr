# frozen_string_literal: true

# Prepended onto ActiveStorage::Previewer where the isolation is asked for, so that
# poppler, muPDF and ffmpeg run in a sandbox. Every previewer funnels its subprocess
# through the same private method, so one hook covers them all — including any previewer
# Rails adds later.
module SandboxedPreviewer
  FONTCONFIG_DIR = "/etc/fonts"

  private

  # Every previewer downloads the blob here before running anything on it.
  # so we override it just to store @sandboxed_input_path and make it readable
  def download_blob_to_tempfile
    super do |tempfile|
      @sandboxed_input_path = tempfile.path

      yield tempfile
    end
  end

  def capture(*argv, to:)
    readable = [@sandboxed_input_path, FONTCONFIG_DIR].compact

    ActiveSupport::Notifications.instrument("decode.sandbox", decoder: File.basename(argv.first)) do
      super(*SandboxedCommand.wrapped_argv(argv, readable:), to:)
    end
  rescue ActiveStorage::PreviewError => error
    # intercept wrapper errors
    raise SandboxedCommand::WrapperFailed, error.message if SandboxedCommand.wrapper_failed?(error.message)

    raise ActiveStorage::PreviewError, error.message.sub(/\A\S+ failed/, "#{argv.first} failed"), error.backtrace
  end
end
