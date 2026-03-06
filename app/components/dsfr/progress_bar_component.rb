# frozen_string_literal: true

module Dsfr
  class ProgressBarComponent < ApplicationComponent
    attr_reader :id, :simulated

    def initialize(simulated: false, id: nil)
      @simulated = simulated
      @id = id || SecureRandom.uuid
    end

    def container_classes
      classes = ['direct-upload', 'fr-fieldset', 'fr-pb-3w']
      classes << 'direct-upload--simulated' if simulated
      classes.join(' ')
    end
  end
end
