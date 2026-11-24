# frozen_string_literal: true

class Profile::APITokenDetailsComponent < ApplicationComponent
  def initialize(id:, name:, networks:, summary:, procedures:)
    @id = id
    @name = name
    @networks = networks
    @summary = summary
    @procedures = procedures
  end

  private

  def procedures_title_id = "#{@id}-procedures"
end
