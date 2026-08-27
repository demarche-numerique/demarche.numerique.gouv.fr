# frozen_string_literal: true

require "open3"

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
  VIPSTHUMBNAIL = "/usr/bin/vipsthumbnail"
  DECODERS = [VIPS, VIPSHEADER, VIPSTHUMBNAIL].freeze
  MIN_VERSION = Gem::Version.new("8.13")

  SANDBOX_ENV = { "VIPS_BLOCK_UNTRUSTED" => "1" }.freeze

  # lipvips prints warning with a pid and timestamp
  NOISE = /^\(process:\d+\): VIPS-|^(?:memory|error buffer|vips_threadset_free):/

  # --vips-leak has libvips report its peak allocation : memory: high-water mark 4.42 MB
  PEAK_MEMORY = /^memory: high-water mark ([\d.]+) (bytes|KB|MB|GB|TB)$/
  UNITS = { "bytes" => 1, "KB" => 1.kilobyte, "MB" => 1.megabyte, "GB" => 1.gigabyte, "TB" => 1.terabyte }.freeze

  # Against decompression bombs: small files but huge decoded image returned to the process
  # an A3 scan at 600 dpi decodes to about 200 MB, a 100 megapixel photograph to 300 MB.
  MAX_DECODED_BYTES = 512.megabytes
  # The first line vipsheader prints, once the path it echoes is taken off:
  #   316x352 uchar, 4 bands, srgb, pngload
  # The four fields the ceiling is computed from are read there — before any metadata,
  # where a value carrying a "width: 1" line of its own cannot reach.
  SUMMARY = /\A(?<width>\d+)x(?<height>\d+) (?<format>\w+), (?<bands>\d+) bands?, /
  FORMAT_BYTES = {
    "uchar" => 1, "char" => 1, "ushort" => 2, "short" => 2, "uint" => 4, "int" => 4,
    "float" => 4, "double" => 8, "complex" => 8, "dpcomplex" => 16,
  }.freeze

  class << self
    def ensure_usable!
      DECODERS.each do |decoder|
        raise "#{decoder} is missing, install the libvips-tools package" if !File.executable?(decoder)
      end
      raise "libvips #{version} ignores VIPS_BLOCK_UNTRUSTED, the sandbox needs #{MIN_VERSION} or newer" if version < MIN_VERSION
    end

    def version
      Gem::Version.new(Open3.capture3(VIPS, "--version").first[/\d+\.\d+\.\d+/])
    end

    # The fields of the upload's header, by vipsheader in the sandbox — no pixel decoded —
    # an integer typed as one, the way libvips holds it:
    #   header(rotated_jpg)   -> { "width" => 200, "orientation" => 8, "vips-loader" => "jpegload", … }
    def header(path)
      output, error, status = run([VIPSHEADER, "-a", "--", path], readable: [path])
      raise Vips::Error, "vipsheader: #{failure_message(error, status)}" if !status.success?

      summary, *lines = output.delete_prefix("#{path}: ").lines
      size = SUMMARY.match(summary)
      raise Vips::Error, "vipsheader: #{summary.strip}" if size.nil?

      # Only the lines that open a field count — and the summary, merged last, is the
      # word on the size.
      fields = lines.grep(/\A[\w.-]+: /).to_h { it.chomp.split(": ", 2) }.transform_values { Integer(it, exception: false) || it }
      fields.merge("width" => size[:width].to_i, "height" => size[:height].to_i, "bands" => size[:bands].to_i, "format" => size[:format])
    end

    def refuse_if_too_large(header)
      width, height, bands, format = header.values_at("width", "height", "bands", "format")
      decoded = width * height * bands * FORMAT_BYTES.fetch(format, 1)
      return if decoded <= MAX_DECODED_BYTES

      raise Vips::Error, "#{width}x#{height}, #{bands} bands of #{format}: too large to decode"
    end

    # Content disarm and reconstruction: the upload is decoded in the sandbox and rebuilt
    # as a stripped PNG, so that only pixels libvips wrote reach this process.
    def disarm(path, autorotate: false, **load_opts)
      refuse_if_too_large(header(path))

      Tempfile.create(["disarmed", ".png"]) do |png|
        # Rotated by the loader as it reads if needed
        source = "#{path}[access=sequential#{',autorotate=true' if autorotate}]"

        # Do not compress output to spare cpu
        # compression=0: the PNG is read back and deleted at once, so deflating it only
        # burns CPU — the default level spends 74 s of the 60 s budget on a large image.
        target = "#{png.path}[compression=0,strip=true]"

        ActiveSupport::Notifications.instrument("decode.sandbox", decoder: "vips") do |payload|
          _, error, status = run([VIPS, "--vips-leak", "copy", source, target], readable: [path], writable: [png.path])
          payload[:peak_memory] = peak_memory(error)

          raise Vips::Error, "vips copy: #{failure_message(error, status)}" if !status.success?
        end

        # Yielded rather than returned: Tempfile deletes the PNG when the block ends, and
        # read by name, sequentially, nothing of it lingers — neither in libvips' cache
        # nor on the disk. Read through a descriptor, it would.
        yield Vips::Image.new_from_file(png.path, **load_opts)
      end
    end

    def error_message(stderr)
      stderr.lines.grep_v(NOISE).join.strip
    end

    # What libvips said — or, when it died saying nothing, how.
    def failure_message(stderr, status) = error_message(stderr).presence || SandboxedCommand.status_message(status)

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
