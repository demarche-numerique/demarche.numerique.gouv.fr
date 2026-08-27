# frozen_string_literal: true

# libvips reached through a subprocess instead of through FFI, for the mutations
# BlobProcessorJob applies to an upload before storing it.
#
# Only the decode of the user's file is dangerous; once we hold pixels, rotating or
# compositing them is arithmetic. So the decode happens in the sandbox and lands in an
# uncompressed PNG, and everything downstream — WatermarkService above all — keeps
# working on a Vips::Image, in this process, unchanged.
#
# The allow list vips_allowed_loaders.rb installs applies to this process, not to a
# subprocess, so the sandbox asks libvips for VIPS_BLOCK_UNTRUSTED instead.
module SandboxedVips
  VIPS = "/usr/bin/vips"
  VIPSHEADER = "/usr/bin/vipsheader"

  SANDBOX_ENV = { "VIPS_BLOCK_UNTRUSTED" => "1" }.freeze

  # lipvips prints warning with a pid and timestamp
  NOISE = /^\(process:\d+\): VIPS-|^(?:memory|error buffer|vips_threadset_free):/

  # --vips-leak has libvips report its peak allocation : memory: high-water mark 4.42 MB
  PEAK_MEMORY = /^memory: high-water mark ([\d.]+) (bytes|KB|MB|GB|TB)$/
  UNITS = { "bytes" => 1, "KB" => 1.kilobyte, "MB" => 1.megabyte, "GB" => 1.gigabyte, "TB" => 1.terabyte }.freeze

  # Against decompression bombs: small files but huge decoded image returned to the process
  # an A3 scan at 600 dpi decodes to about 200 MB, a 100 megapixel photograph to 300 MB.
  MAX_DECODED_BYTES = 512.megabytes
  DIMENSIONS = /(\d+)x(\d+) (\w+), (\d+) bands?/
  FORMAT_BYTES = {
    "uchar" => 1, "char" => 1, "ushort" => 2, "short" => 2, "uint" => 4, "int" => 4,
    "float" => 4, "double" => 8, "complex" => 8, "dpcomplex" => 16,
  }.freeze

  class << self
    # ex: header(rotated_jpg, "orientation")   -> "8"
    #     header(interlaced_png, "interlaced") -> "1"
    def header(path, field)
      value, _, status = run([VIPSHEADER, "-f", field, "--", path], readable: [path])

      status.success? ? value.chomp : nil
    end

    # Yields the decoded image
    def decode(path, autorotate: false)
      refuse_if_too_large(path)

      Dir.mktmpdir do |directory|
        target = File.join(directory, "decoded.png")
        operation = autorotate ? "autorot" : "copy"

        source = "#{path}[access=sequential]"

        ActiveSupport::Notifications.instrument("decode.sandbox", decoder: "vips") do |payload|
          _, error, status = run([VIPS, "--vips-leak", operation, source, "#{target}[compression=1]"], readable: [path], writable: [directory])
          payload[:peak_memory] = peak_memory(error)

          raise Vips::Error, "vips #{operation}: #{error_message(error).presence || status}" if !status.success?
        end

        yield Vips::Image.new_from_file(target)
      end
    end

    def refuse_if_too_large(path)
      description, _, status = run([VIPSHEADER, path], readable: [path])
      return if !status.success?

      width, height, format, bands = DIMENSIONS.match(description)&.captures
      return if width.nil?

      decoded = width.to_i * height.to_i * bands.to_i * FORMAT_BYTES.fetch(format, 1)
      return if decoded <= MAX_DECODED_BYTES

      raise Vips::Error, "#{width}x#{height}, #{bands} bands of #{format}: too large to decode"
    end

    def error_message(stderr)
      stderr.lines.grep_v(NOISE).join.strip
    end

    def peak_memory(stderr)
      size, unit = PEAK_MEMORY.match(stderr)&.captures
      return if size.nil?

      (size.to_f * UNITS.fetch(unit)).round
    end

    private

    def run(argv, readable: [], writable: [])
      SandboxedCommand.run(argv, readable:, writable:, env: SANDBOX_ENV)
    end
  end
end
