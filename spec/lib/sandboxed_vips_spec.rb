# frozen_string_literal: true

describe SandboxedVips, :external_deps, if: SANDBOX_USABLE do
  let(:rotated) { Rails.root.join("spec/fixtures/files/image-rotated.jpg").to_s }
  let(:upright) { Rails.root.join("spec/fixtures/files/image-no-rotation.jpg").to_s }

  describe ".header" do
    it "reads a field" do
      expect(described_class.header(rotated, "orientation")).to eq("8")
    end

    it "returns nil when the file has no such field" do
      expect(described_class.header(upright, "interlaced")).to be_nil
    end

    it "returns nil rather than raising when the file is not an image" do
      expect(described_class.header(Rails.root.join("spec/fixtures/files/not-an-image.jpg").to_s, "orientation")).to be_nil
    end
  end

  describe ".decode" do
    it "yields the decoded pixels" do
      described_class.decode(rotated) do |image|
        expect([image.width, image.height]).to eq([200, 200])
      end
    end

    it "applies the EXIF rotation when asked" do
      described_class.decode(rotated, autorotate: true) do |image|
        expect(image.get("orientation")).to eq(1)
      end
    end

    it "leaves the image upright when not asked" do
      described_class.decode(rotated) do |image|
        expect(image.get("orientation")).to eq(8)
      end
    end

    # The header says what decoding would cost before anything is allocated, which is
    # the only moment a decompression bomb can be refused rather than survived.
    it "refuses a file whose header says decoding it would not be reasonable" do
      stub_const("SandboxedVips::MAX_DECODED_BYTES", 1000)

      expect { described_class.decode(rotated) { nil } }
        .to raise_error(Vips::Error, "200x200, 3 bands of uchar: too large to decode")
    end

    # What the decoding cost is no longer visible in this process's memory, so the
    # decoder has to say it: this is the only place that number comes from.
    it "reports what the decoding cost" do
      events = []

      ActiveSupport::Notifications.subscribed(-> (event) { events << event }, "decode.sandbox") do
        described_class.decode(rotated) { nil }
      end

      expect(events.sole.payload).to include(decoder: "vips", peak_memory: be_positive)
    end

    # The out-of-memory kill is the failure worth seeing, and the only one that writes
    # nothing at all: without the status there would be nothing to read in Sentry.
    it "reports the signal when the decoder is killed" do
      allow(SandboxedCommand).to receive(:wrapped_argv).and_return(["/bin/sh", "-c", "kill -9 $$"])

      expect { described_class.decode(rotated) { nil } }.to raise_error(Vips::Error, /SIGKILL/)
    end

    # SVG is on ALLOWED_VIPS_LOADERS for the overlay StaticMapService builds itself,
    # which never comes through here. The sandbox asks for VIPS_BLOCK_UNTRUSTED, and
    # svgload is in the family that refuses.
    it "refuses a loader we do not trust with an upload" do
      svg = Tempfile.new(["probe", ".svg"])
      svg.write('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>')
      svg.flush

      expect { described_class.decode(svg.path) { nil } }.to raise_error(Vips::Error, /is not a known file format/)
    ensure
      svg.close!
    end

    # The watermark used to composite onto an image loaded straight from the upload;
    # it now gets one loaded from the sandbox's PNG. Same pixels, different loader.
    it "yields an image WatermarkService can still composite onto" do
      described_class.decode(rotated) do |image|
        watermarked = WatermarkService.new.apply(image, format: "image/jpeg")

        expect([watermarked.width, watermarked.height]).to eq([200, 200])
      end
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

    # The dangerous one: nil reads as "no orientation to fix", and the mutation is
    # skipped for every upload the machine sees, without a word.
    it "raises rather than answering as a file with no such field" do
      expect { described_class.header(rotated, "orientation") }
        .to raise_error(SandboxedCommand::WrapperFailed, /Can't find source path/)
    end

    it "raises rather than as a file libvips could not decode" do
      expect { described_class.decode(rotated) { nil } }.to raise_error(SandboxedCommand::WrapperFailed)
    end
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
