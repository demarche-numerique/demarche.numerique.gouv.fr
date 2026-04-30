# frozen_string_literal: true

require "administrate/field/base"

class FeaturesField < Administrate::Field::Base
  def self.available_features(group)
    Flipper.features.filter { it.key.start_with?("#{group}_") }
  end

  def available_features
    self.class.available_features(resource.class.name.downcase)
  end
end
