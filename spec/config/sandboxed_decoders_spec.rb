# frozen_string_literal: true

# What the rest of the suite cannot check, since a prepend cannot be undone: what each
# patch does to Active Storage. The prepends and the paths are intercepted rather than
# performed. The guard is not here but on the hooks that call these — that BWRAP_ISOLATION
# is absent under test is what the last example rests on.
describe SandboxedDecoders do
  describe ".patch_previewer!" do
    it "hands the previewers over to the sandbox where the isolation is asked for" do
      stub_const("SandboxedCommand::ENABLED", true)

      allow(described_class).to receive(:ensure_runs_in_sandbox!)

      expect(ActiveStorage::Previewer).to receive(:prepend).with(SandboxedPreviewer)
      expect(Rails.application.config.active_storage.paths).to receive(:merge!)
        .with({ pdftoppm: "/usr/bin/pdftoppm", mutool: "/usr/bin/mutool", ffmpeg: "/usr/bin/ffmpeg" })

      described_class.patch_previewer!
    end
  end

  # Active Storage asks the host whether to offer a previewer; the sandbox is where it
  # will run. A binary that is installed and cannot start there would be offered and then
  # fail on every upload of that type, so boot names it instead.
  describe ".ensure_runs_in_sandbox!" do
    it "refuses a previewer that is installed and will not run in the sandbox" do
      allow(SandboxedCommand).to receive(:run)
        .and_return(["", "error while loading shared libraries: libpoppler.so", instance_double(Process::Status, success?: false)])

      expect { described_class.ensure_runs_in_sandbox!(["/usr/bin/pdftoppm", "-v"]) }
        .to raise_error(RuntimeError, %r{/usr/bin/pdftoppm will not run in the sandbox})
    end

    # Absent is not a fault: Active Storage offers no previewer for that type, sandbox or
    # not, so there is nothing to refuse a boot over.
    it "passes over a previewer that is not installed" do
      expect(SandboxedCommand).not_to receive(:run)

      expect { described_class.ensure_runs_in_sandbox!(["/usr/bin/no-such-previewer"]) }.not_to raise_error
    end
  end

  describe ".patch_variation!" do
    it "hands the variants over to the sandbox where the isolation is asked for" do
      stub_const("SandboxedCommand::ENABLED", true)

      expect(ActiveStorage::Variation).to receive(:prepend).with(SandboxedVariation)

      described_class.patch_variation!
    end
  end

  # The default, and what the suite runs under: Active Storage decodes as it always has.
  it "is not patched onto Active Storage in this process" do
    expect(ActiveStorage::Variation.ancestors).not_to include(SandboxedVariation)
    expect(ActiveStorage::Previewer.ancestors).not_to include(SandboxedPreviewer)
  end
end
