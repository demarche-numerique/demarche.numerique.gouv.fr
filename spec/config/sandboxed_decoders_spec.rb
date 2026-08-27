# frozen_string_literal: true

# What the rest of the suite cannot check, since a prepend cannot be undone: that the
# hooks reach Active Storage where the isolation is asked for, and nowhere else. The
# prepends and the paths are intercepted rather than performed, so this says what would
# happen without it happening.
describe SandboxedDecoders do
  describe ".graft!" do
    it "hands Active Storage over to the sandbox where the isolation is asked for" do
      stub_const("SandboxedCommand::ENABLED", true)

      expect(ActiveStorage::Previewer).to receive(:prepend).with(SandboxedPreviewer)
      expect(ActiveStorage::Variation).to receive(:prepend).with(SandboxedVariation)
      expect(Rails.application.config.active_storage.paths).to receive(:merge!)
        .with({ pdftoppm: "/usr/bin/pdftoppm", mutool: "/usr/bin/mutool", ffmpeg: "/usr/bin/ffmpeg" })

      described_class.graft!
    end

    it "leaves it alone everywhere else" do
      stub_const("SandboxedCommand::ENABLED", false)

      expect(ActiveStorage::Previewer).not_to receive(:prepend)
      expect(ActiveStorage::Variation).not_to receive(:prepend)
      expect(Rails.application.config.active_storage.paths).not_to receive(:merge!)

      described_class.graft!
    end
  end

  # The default, and what the suite runs under: Active Storage decodes as it always has.
  it "is not grafted onto Active Storage in this process" do
    expect(ActiveStorage::Variation.ancestors).not_to include(SandboxedVariation)
    expect(ActiveStorage::Previewer.ancestors).not_to include(SandboxedPreviewer)
  end
end
