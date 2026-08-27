# frozen_string_literal: true

# Prepended onto ActiveStorage::Previewer where the isolation is asked for, so that
# poppler, muPDF and ffmpeg run in a sandbox. Every previewer funnels its subprocess
# through the same private method, so one hook covers them all — including any previewer
# Rails adds later.
module SandboxedPreviewer
  FONTS = [
    "/etc/fonts",            # fontconfig configuration
    "/usr/share/fontconfig", # where the links in /etc/fonts/conf.d point
    "/usr/share/fonts",      # the font files
    "/var/cache/fontconfig", # fontconfig cache, or every run rescans the fonts
  ].freeze

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
    # The font dirs are best guesses, and bwrap fails if a dir is missing.
    readable = [@sandboxed_input_path, *FONTS.filter { File.exist?(it) }].compact

    ActiveSupport::Notifications.instrument("decode.sandbox", decoder: File.basename(argv.first)) do
      super(*SandboxedCommand.wrapped_argv(argv, readable:), to:)
    end
  rescue ActiveStorage::PreviewError => error
    # intercept wrapper errors
    message = error.message.scrub
    raise SandboxedCommand::WrapperFailed, message if SandboxedCommand.wrapper_failed?(message)

    raise ActiveStorage::PreviewError, message.sub(/\A\S+ failed/, "#{argv.first} failed"), error.backtrace
  end
end
