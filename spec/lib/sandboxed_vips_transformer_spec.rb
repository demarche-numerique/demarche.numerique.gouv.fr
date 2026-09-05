# frozen_string_literal: true

describe SandboxedVipsTransformer, :external_deps, if: SANDBOX_USABLE do
  # 316x352, so a 200x200 limit shrinks it and a 400x400 limit leaves it alone.
  let(:source) { Rails.root.join("spec/fixtures/files/logo_test_procedure.png").open }

  # Straight to the transformer, the way ActiveStorage::Variation reaches it once
  # grafted: the transformations minus the format, which it is handed apart.
  def transform(transformations, file = source)
    described_class.new(transformations.except(:format)).transform(file, format: transformations.fetch(:format)) do |output|
      image = Vips::Image.new_from_file(output.path)
      [image.width, image.height]
    end
  end

  it "fits the image inside the limit" do
    expect(transform(resize_to_limit: [200, 200], format: :png)).to eq([180, 200])
  end

  it "never enlarges a smaller image" do
    expect(transform(resize_to_limit: [400, 400], format: :png)).to eq([316, 352])
  end

  it "enlarges to fit the box when asked to fit rather than to limit" do
    expect(transform(resize_to_fit: [400, 400], format: :png)).to eq([359, 400])
  end

  it "fills the box and trims what sticks out" do
    expect(transform(resize_to_fill: [200, 200], format: :png)).to eq([200, 200])
  end

  it "refuses a resize it cannot tell apart from another" do
    expect { transform(resize_to_limit: [200, 200], resize_to_fill: [200, 200], format: :png) }
      .to raise_error(described_class::UnsupportedTransformation, /resize_to_fill/)
  end

  it "converts to the requested format" do
    described_class.new(resize_to_limit: [200, 200]).transform(source, format: :jpeg) do |output|
      expect(Vips::Image.new_from_file(output.path).get("vips-loader")).to eq("jpegload")
    end
  end

  it "refuses a transformation it cannot reproduce" do
    expect { transform(rotate: 90, format: :png) }
      .to raise_error(described_class::UnsupportedTransformation, /rotate/)
  end

  it "raises the error the in-process path raised on bytes that are not an image" do
    not_an_image = Rails.root.join("spec/fixtures/files/not-an-image.jpg").open

    expect { transform({ resize_to_limit: [200, 200], format: :png }, not_an_image) }
      .to raise_error(Vips::Error, /is not a known file format/)
  end

  it "refuses a source whose header says decoding it would not be reasonable" do
    stub_const("SandboxedVips::MAX_DECODED_BYTES", 1000)

    expect { transform(resize_to_limit: [200, 200], format: :png) }
      .to raise_error(Vips::Error, /too large to decode/)
  end

  it "reports what the variant cost" do
    events = []

    ActiveSupport::Notifications.subscribed(-> (event) { events << event }, "decode.sandbox") do
      transform(resize_to_limit: [200, 200], format: :png)
    end

    expect(events.sole.payload).to include(decoder: "vipsthumbnail", peak_memory: be_positive)
  end

  # A killed decoder writes nothing, and that is the failure worth reading in Sentry.
  it "reports the signal when the decoder is killed" do
    allow(SandboxedCommand).to receive(:wrapped_argv).and_return(["/bin/sh", "-c", "kill -9 $$"])

    expect { transform(resize_to_limit: [200, 200], format: :png) }.to raise_error(Vips::Error, /SIGKILL/)
  end
end
