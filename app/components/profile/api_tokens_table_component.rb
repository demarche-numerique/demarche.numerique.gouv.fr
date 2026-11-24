# frozen_string_literal: true

class Profile::APITokensTableComponent < ApplicationComponent
  def initialize(labelledby:)
    @labelledby = labelledby
  end
end
