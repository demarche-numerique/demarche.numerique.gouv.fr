# frozen_string_literal: true

describe SandboxedPreviewer, :external_deps, if: SANDBOX_USABLE && ActiveStorage::Previewer::PopplerPDFPreviewer.pdftoppm_exists? do
  # The graft is the initializer's job, and it only happens where the isolation is
  # asked for; here the module is exercised on classes that carry it themselves, so
  # nothing is prepended onto Active Storage for the rest of the suite.
  let(:previewer_class) { Class.new(ActiveStorage::Previewer::PopplerPDFPreviewer) { prepend SandboxedPreviewer } }
  let(:bare_previewer_class) { Class.new(ActiveStorage::Previewer) { prepend SandboxedPreviewer } }

  # What the graft hands Active Storage along with the module: its binary by its
  # absolute path, since the sandbox has no PATH to resolve a bare name against.
  before { allow(ActiveStorage).to receive(:paths).and_return(pdftoppm: "/usr/bin/pdftoppm") }

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/file.pdf").open,
      filename: "file.pdf",
      content_type: "application/pdf"
    )
  end

  it "previews a PDF through the sandbox" do
    expect(SandboxedCommand).to receive(:wrapped_argv).once.and_call_original

    preview = nil
    previewer_class.new(blob).preview { |io:, **| preview = io.read }

    expect(preview.byteslice(1, 3)).to eq("PNG")
  end

  it "hands pdftoppm nothing but its own input" do
    sandboxed = nil
    allow(SandboxedCommand).to receive(:wrapped_argv).and_wrap_original do |original, argv, **options|
      sandboxed = original.call(argv, **options)
    end

    previewer_class.new(blob).preview { |**| nil }

    system_paths = %w[/lib /lib64 /usr/lib /usr/bin/pdftoppm /etc/fonts]
    bound = sandboxed.each_cons(3).filter { |flag, _, _| flag == "--ro-bind" }.map(&:last)

    expect(bound - system_paths).to eq([sandboxed.last])
  end

  it "reports what the preview cost, under the decoder that ran" do
    events = []

    ActiveSupport::Notifications.subscribed(-> (event) { events << event }, "decode.sandbox") do
      previewer_class.new(blob).preview { |**| nil }
    end

    expect(events.sole.payload).to include(decoder: "pdftoppm")
  end

  # PreviewError opens with the command it ran, and every previewer's command is bwrap
  # now: "bwrap failed" says nothing about which decoder gave up, and reads the same
  # whichever one did.
  it "names the decoder that failed rather than the sandbox" do
    output = Tempfile.new("preview")

    expect { bare_previewer_class.new(blob).send(:capture, "/usr/bin/false", to: output) }
      .to raise_error(ActiveStorage::PreviewError, %r{\A/usr/bin/false failed})
  ensure
    output.close!
  end

  it "tells a sandbox that never started from a decoder that failed" do
    output = Tempfile.new("preview")
    allow(SandboxedCommand).to receive(:wrapped_argv)
      .and_return([SandboxedCommand::BWRAP, "--ro-bind", "/nowhere", "/nowhere", "--", "/usr/bin/true"])

    expect { bare_previewer_class.new(blob).send(:capture, "pdftoppm", to: output) }
      .to raise_error(SandboxedCommand::WrapperFailed, /Can't find source path/)
  ensure
    output.close!
  end
end
