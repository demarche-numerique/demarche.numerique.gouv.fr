# frozen_string_literal: true

class Profile::APITokensTableComponent < ApplicationComponent
  def initialize(labelledby:, rows:)
    @labelledby = labelledby
    @rows = rows
  end
end
