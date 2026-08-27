# frozen_string_literal: true

# Prepended onto ActiveStorage::Variation where the isolation is asked for. Variants are
# the harder half: ruby-vips is in-process, so there is no subprocess to wrap and the
# transformer has to be replaced outright.
module SandboxedVariation
  private

  def transformer
    SandboxedVipsTransformer.new(transformations.except(:format))
  end
end
