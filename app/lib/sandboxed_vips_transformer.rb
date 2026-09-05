# frozen_string_literal: true

# Replaces the Vips transformer Active Storage would use. Resizing only:
# every other transformation is a back and forth between ImageProcessing and
# libvips over an image held in memory through FFI, which does not map onto one command
# in one process. Anything else raises rather than coming out silently untransformed.
class SandboxedVipsTransformer < ActiveStorage::Transformers::Transformer
  class UnsupportedTransformation < StandardError; end

  SIZE_ARGS = {
    resize_to_limit: -> (width, height) { ["--size", "#{width}x#{height}>"] },
    resize_to_fit: -> (width, height) { ["--size", "#{width}x#{height}"] },
    resize_to_fill: -> (width, height) { ["--size", "#{width}x#{height}", "--smartcrop", "centre"] },
  }.freeze

  # vips_allowed_loaders.rb narrows this process, not a subprocess, so the loader
  # control falls back to what libvips reads from its environment.
  SANDBOX_ENV = { "VIPS_BLOCK_UNTRUSTED" => "1" }.freeze

  VIPSTHUMBNAIL = "/usr/bin/vipsthumbnail"

  private

  def process(file, format:)
    size = size_args
    SandboxedVips.refuse_if_too_large(file.path)

    output = Tempfile.new(["variant", ".#{format}"], binmode: true)
    argv = [VIPSTHUMBNAIL, "--vips-leak", *size, "-o", output.path, "--", file.path]

    ActiveSupport::Notifications.instrument("decode.sandbox", decoder: "vipsthumbnail") do |payload|
      _, error, status = SandboxedCommand.run(argv, readable: [file.path], writable: [output.path], env: SANDBOX_ENV)

      # instrument emits its event even when the block raises
      payload[:peak_memory] = SandboxedVips.peak_memory(error)

      raise Vips::Error, SandboxedVips.error_message(error).presence || "vipsthumbnail: #{status}" if !status.success?
    end

    output.tap(&:rewind)
  rescue StandardError
    output&.close!
    raise
  end

  def size_args
    name, (width, height) = transformations.first
    resize = transformations.one? && SIZE_ARGS[name]

    raise UnsupportedTransformation, "not supported by the sandboxed transformer: #{transformations.keys.inspect}" if !resize

    resize.call(width, height)
  end
end
