# frozen_string_literal: true

describe "DISABLE_IMAGE_PROCESSING" do
  it "leaves Active Storage free to transform when unset" do
    expect(ActiveStorage.variable_content_types).to include("image/png")
    expect(ActiveStorage.previewers).not_to be_empty
  end

  it "empties both lists when set" do
    config = ActiveSupport::OrderedOptions.new
    config.variable_content_types = ["image/png"]
    config.previewers = [ActiveStorage::Previewer::PopplerPDFPreviewer]
    allow(Rails.application.config).to receive(:active_storage).and_return(config)
    allow(ENV).to receive(:enabled?).and_call_original
    allow(ENV).to receive(:enabled?).with("DISABLE_IMAGE_PROCESSING").and_return(true)

    load Rails.root.join("config/initializers/image_processing.rb")

    expect(config.variable_content_types).to eq([])
    expect(config.previewers).to eq([])
  end
end
