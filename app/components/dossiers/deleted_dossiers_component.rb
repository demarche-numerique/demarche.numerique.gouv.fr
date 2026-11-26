# frozen_string_literal: true

class Dossiers::DeletedDossiersComponent < ApplicationComponent
  include DossierHelper

  attr_reader :heading_level

  def initialize(deleted_dossiers:, heading_level: :h1)
    @deleted_dossiers = deleted_dossiers
    @heading_level = heading_level
  end

  def role
    controller.try(:nav_bar_profile)
  end
end
