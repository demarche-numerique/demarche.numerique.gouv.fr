# frozen_string_literal: true

# Guard for specs shelling out to binaries (typst, verapdf, ...) that only
# the :external_deps CI job installs.
module ExternalTools
  def require_tool!(binary)
    return if system("which #{binary}", out: File::NULL, err: File::NULL)

    # On CI the missing binary means the workflow install step broke:
    # skipping would silently drop the only coverage running the real thing.
    raise "#{binary} is required on CI but is not installed" if ENV['CI'].present?

    skip "#{binary} binary not installed"
  end
end

RSpec.configure do |config|
  config.include ExternalTools
end
