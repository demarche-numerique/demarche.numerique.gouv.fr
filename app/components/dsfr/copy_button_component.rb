# frozen_string_literal: true

class Dsfr::CopyButtonComponent < ApplicationComponent
  def initialize(text:, title:, success: nil, title_visible: false)
    @text = text
    @title = title
    @success = success
    @title_visible = title_visible
  end
end
