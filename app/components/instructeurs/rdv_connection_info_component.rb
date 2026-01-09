# frozen_string_literal: true

class Instructeurs::RdvConnectionInfoComponent < ApplicationComponent
  attr_reader :rdv_email, :redirect_path

  def initialize(rdv_email:, redirect_path: nil)
    @rdv_email = rdv_email
    @redirect_path = redirect_path
  end
end
