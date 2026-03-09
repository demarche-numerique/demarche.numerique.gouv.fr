# frozen_string_literal: true

class ProConnectLoginComponent < ApplicationComponent
  def initialize(url: nil, title: :default, heading_level: :h2)
    @url = url
    @title = title
    @heading_level = heading_level
  end

  def before_render
    @url ||= helpers.pro_connect_login_path
  end

  def render?
    ProConnectService.enabled?
  end

  private

  def resolved_title
    case @title
    when :default
      t('.title')
    when nil
      nil
    else
      @title
    end
  end
end
