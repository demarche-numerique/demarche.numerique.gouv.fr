# frozen_string_literal: true

describe SandboxedVips, :external_deps, if: SANDBOX_USABLE do
  let(:rotated) { Rails.root.join("spec/fixtures/files/image-rotated.jpg").to_s }
  let(:upright) { Rails.root.join("spec/fixtures/files/image-no-rotation.jpg").to_s }

  describe ".header" do
    it "reads the fields the file carries, an integer typed as libvips does" do
      expect(described_class.header(rotated)).to include("width" => 200, "orientation" => 8, "vips-loader" => "jpegload")
    end

    it "carries no field the file lacks" do
      expect(described_class.header(upright)).not_to include("interlaced")
    end

    it "reads an interlaced PNG as libvips does" do
      png = Tempfile.new(["interlaced", ".png"])
      Vips::Image.new_from_file(Rails.root.join("spec/fixtures/files/logo_test_procedure.png").to_s).write_to_file(png.path, interlace: true)

      expect(described_class.header(png.path)).to include("interlaced" => 1)
    ensure
      png.close!
    end

    # vipsheader prints a text value as it is, newlines included; the line after the
    # break has no "field: " and once broke the parse for the whole header.
    it "survives a value that spans lines" do
      png = Tempfile.new(["multiline", ".png"])
      image = Vips::Image.new_from_file(Rails.root.join("spec/fixtures/files/logo_test_procedure.png").to_s).copy
      image.set_type(GObject::GSTR_TYPE, "png-comment-0-Comment", "line 1\nline 2")
      image.write_to_file(png.path)

      expect(described_class.header(png.path)).to include("width" => 316, "png-comment-0-Comment" => "line 1")
    ensure
      png.close!
    end

    # A value can carry "width: 1" lines of its own: the size must not be read from it.
    it "takes the size from the summary, whatever a value says" do
      png = Tempfile.new(["inject", ".png"])
      image = Vips::Image.new_from_file(Rails.root.join("spec/fixtures/files/logo_test_procedure.png").to_s).copy
      image.set_type(GObject::GSTR_TYPE, "png-comment-0-Comment", "x\nwidth: 1\nheight: 1\nbands: 1\nformat: uchar")
      image.write_to_file(png.path)

      expect(described_class.header(png.path)).to include("width" => 316, "height" => 352, "bands" => 4, "format" => "uchar")
    ensure
      png.close!
    end

    # The path is taken off the summary as it was given, so a newline in the upload's
    # extension — which the tempfile keeps — cannot split the summary either.
    it "reads a file whose name holds a newline" do
      png = Tempfile.new(["probe\nwidth: 1\n", ".png"], binmode: true)
      png.write(Rails.root.join("spec/fixtures/files/logo_test_procedure.png").binread)
      png.flush

      expect(described_class.header(png.path)).to include("width" => 316, "height" => 352)
    ensure
      png.close!
    end

    it "raises as Vips::Image does when the file is not an image" do
      expect { described_class.header(Rails.root.join("spec/fixtures/files/not-an-image.jpg").to_s) }.to raise_error(Vips::Error)
    end
  end

  describe ".disarm" do
    it "yields the decoded pixels" do
      size = nil
      described_class.disarm(rotated) { |image| size = [image.width, image.height] }

      expect(size).to eq([200, 200])
    end

    # Metadata is stripped off the copy: no EXIF, XMP or ICC for pngload to reparse in
    # this process, and no GPS or camera trail left on a watermarked identity document.
    it "strips the upload's metadata off the copy" do
      fields = nil
      described_class.disarm(rotated, autorotate: true) { |image| fields = image.get_fields }

      expect(fields.grep(/exif|icc|orientation/i)).to be_empty
    end

    # A rotation is not streamed: `vips autorot` unfolds the decoded image through a
    # temporary file, and on the sandbox's 100 MB tmpfs that fails for any large photo
    # held in portrait. Rotated by the loader as it reads, it stays in memory. With the
    # metadata stripped, the pixels are the only witness that rotation did or did not run.
    it "rotates the pixels on load when asked, and leaves them as stored otherwise" do
      photo = Tempfile.new(["portrait", ".jpg"], binmode: true)
      Vips::Image.black(7000, 6000, bands: 3).copy.tap { it.set_type(GObject::GINT_TYPE, "orientation", 6) }.write_to_file(photo.path)

      rotated_size = upright_size = nil
      described_class.disarm(photo.path, autorotate: true, access: :sequential) { |image| rotated_size = [image.width, image.height] }
      described_class.disarm(photo.path, autorotate: false, access: :sequential) { |image| upright_size = [image.width, image.height] }

      expect(rotated_size).to eq([6000, 7000])
      expect(upright_size).to eq([7000, 6000])
    ensure
      photo&.close!
    end

    # Read by name and sequentially, the PNG is closed at the end of the read and gone
    # with the block. Read through a descriptor, libvips' operation cache would keep it
    # open — and its disk space allocated — long after the file was deleted.
    it "leaves no descriptor on the copy it deleted" do
      3.times { described_class.disarm(rotated, access: :sequential, &:avg) }

      deleted = Dir.glob("/proc/self/fd/*").count { File.symlink?(it) && File.readlink(it).include?("(deleted)") }
      expect(deleted).to eq(0)
    end

    # The header says what decoding would cost before anything is allocated, which is
    # the only moment a decompression bomb can be refused rather than survived.
    it "refuses a file whose header says decoding it would not be reasonable" do
      stub_const("SandboxedVips::MAX_DECODED_BYTES", 1000)

      expect { described_class.disarm(rotated) { nil } }
        .to raise_error(Vips::Error, "200x200, 3 bands of uchar: too large to decode")
    end

    # The tempfile Active Storage downloads to carries the upload's extension, raw. A
    # name that reads like a header line must not pass for one.
    it "refuses on what the header says, not on what the file is named" do
      stub_const("SandboxedVips::MAX_DECODED_BYTES", 1000)
      bomb = Tempfile.new(["bomb.1x1 uchar, 1 band", ".jpg"], binmode: true)
      bomb.write(File.binread(rotated))
      bomb.flush

      expect { described_class.disarm(bomb.path) { nil } }
        .to raise_error(Vips::Error, "200x200, 3 bands of uchar: too large to decode")
    ensure
      bomb&.close!
    end

    # What the decoding cost is no longer visible in this process's memory, so the
    # decoder has to say it: this is the only place that number comes from.
    it "reports what the decoding cost" do
      events = []

      ActiveSupport::Notifications.subscribed(-> (event) { events << event }, "decode.sandbox") do
        described_class.disarm(rotated) { nil }
      end

      expect(events.sole.payload).to include(decoder: "vips", peak_memory: be_positive)
    end

    # The out-of-memory kill is the failure worth seeing, and the only one that writes
    # nothing at all: without the status there would be nothing to read in Sentry. Killed
    # inside the sandbox, as it would be: bwrap reports it as an exit, not a signal.
    it "reports the signal when the decoder is killed" do
      allow(SandboxedCommand).to receive(:wrapped_argv).and_wrap_original { |original, *| original.call(["/bin/sh", "-c", "kill -9 $$"]) }

      expect { described_class.disarm(rotated) { nil } }.to raise_error(Vips::Error, /SIGKILL/)
    end

    # SVG is on ALLOWED_VIPS_LOADERS for the overlay StaticMapService builds itself,
    # which never comes through here. The sandbox asks for VIPS_BLOCK_UNTRUSTED, and
    # svgload is in the family that refuses.
    it "refuses a loader we do not trust with an upload" do
      svg = Tempfile.new(["probe", ".svg"])
      svg.write('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>')
      svg.flush

      expect { described_class.disarm(svg.path) { nil } }.to raise_error(Vips::Error, /is not a known file format/)
    ensure
      svg.close!
    end

    # The watermark used to composite onto an image loaded straight from the upload;
    # it now gets one loaded from the sandbox's PNG. Same pixels, different loader.
    it "yields an image WatermarkService can still composite onto" do
      size = nil
      described_class.disarm(rotated) do |image|
        watermarked = WatermarkService.new.apply(image, format: "image/jpeg")
        size = [watermarked.width, watermarked.height]
      end

      expect(size).to eq([200, 200])
    end
  end

  # bwrap fails before the decoder ever runs — a namespace refused, a bind it cannot
  # make — and exits 1 saying so, exactly as a decoder handed a corrupt file does. Read
  # as one, a machine that lost its sandbox reports as a run of bad uploads.
  describe "when the sandbox will not start" do
    before do
      allow(SandboxedCommand).to receive(:wrapped_argv)
        .and_return([SandboxedCommand::BWRAP, "--ro-bind", "/nowhere", "/nowhere", "--", "/usr/bin/true"])
    end

    # The dangerous one: an empty header reads as "no orientation to fix", and the
    # mutation is skipped for every upload the machine sees, without a word.
    it "raises rather than answering as a file with no such field" do
      expect { described_class.header(rotated) }
        .to raise_error(SandboxedCommand::WrapperFailed, /Can't find source path/)
    end

    it "raises rather than as a file libvips could not decode" do
      expect { described_class.disarm(rotated) { nil } }.to raise_error(SandboxedCommand::WrapperFailed)
    end
  end
end

describe SandboxedVips, ".ensure_usable!", :external_deps do
  # Without the tools BlobProcessorJob shells out to, boot passes and every image dies
  # later as a bind bwrap cannot make — so the missing package is named at boot instead.
  it "refuses without the libvips tools" do
    stub_const("SandboxedVips::DECODERS", ["/usr/bin/no-such-vips"])

    expect { described_class.ensure_usable! }.to raise_error(RuntimeError, /libvips-tools/)
  end

  # A libvips older than 8.13 ignores VIPS_BLOCK_UNTRUSTED and decodes in the subprocess
  # what the sandbox exists to refuse — silently. Named at boot rather than trusted.
  it "refuses a libvips too old to block untrusted loaders" do
    allow(described_class).to receive(:version).and_return(Gem::Version.new("8.12.1"))

    expect { described_class.ensure_usable! }.to raise_error(RuntimeError, /8\.12\.1 ignores VIPS_BLOCK_UNTRUSTED/)
  end

  it "reads the version of the libvips it would run" do
    expect(described_class.version).to be >= SandboxedVips::MIN_VERSION
  end
end

describe SandboxedVips, ".error_message", :external_deps do
  # A real stderr of a failed decode: the pid and the timestamp are the point — left
  # in, two occurrences of one failure never carry the same message — and so is the
  # "error buffer:" line, which would otherwise say everything twice.
  it "keeps the failure and drops what libvips says around it" do
    stderr = "\n(process:519761): VIPS-WARNING **: 08:58:15.213: unable to load \"vips-openslide.so\"\n" \
             "VipsForeignLoad: \"probe.svg\" is not a known file format\n" \
             "memory: high-water mark 0 bytes\n" \
             "error buffer: VipsForeignLoad: \"probe.svg\" is not a known file format\n" \
             "vips_threadset_free: peak of 0 threads\n"

    expect(described_class.error_message(stderr)).to eq('VipsForeignLoad: "probe.svg" is not a known file format')
  end
end

describe SandboxedVips, ".peak_memory", :external_deps do
  it "reads what libvips reports, in bytes" do
    expect(described_class.peak_memory("memory: high-water mark 4.42 MB\n")).to eq(4_634_706)
  end

  it "reads a decode that allocated nothing at all" do
    expect(described_class.peak_memory("memory: high-water mark 0 bytes\n")).to eq(0)
  end

  it "is nil when the decoder never got far enough to report" do
    expect(described_class.peak_memory("bwrap: Can't find source path /nowhere\n")).to be_nil
  end
end

describe SandboxedVips, ".refuse_if_too_large", :external_deps do
  it "refuses a header whose decoded size is over the ceiling" do
    expect { described_class.refuse_if_too_large("width" => 20000, "height" => 20000, "bands" => 3, "format" => "uchar") }
      .to raise_error(Vips::Error, "20000x20000, 3 bands of uchar: too large to decode")
  end

  # An A3 scan at 600 dpi.
  it "lets the largest legitimate scans through" do
    expect(described_class.refuse_if_too_large("width" => 7000, "height" => 9900, "bands" => 3, "format" => "uchar")).to be_nil
  end

  # 300 MB of pixels, 600 MB once the 16-bit format is counted.
  it "counts the format as much as the pixels" do
    expect { described_class.refuse_if_too_large("width" => 10000, "height" => 10000, "bands" => 3, "format" => "ushort") }
      .to raise_error(Vips::Error, "10000x10000, 3 bands of ushort: too large to decode")
  end
end
