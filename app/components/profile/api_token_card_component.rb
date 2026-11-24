# frozen_string_literal: true

class Profile::APITokenCardComponent < ApplicationComponent
  def initialize(unfold_expired: false)
    @unfold_expired = unfold_expired
  end

  private

  def render?
    current_administrateur.present?
  end

  def api_tokens
    @api_tokens ||= current_administrateur.api_tokens.order(created_at: :desc).to_a
  end

  def valid_api_tokens = api_tokens.reject(&:expired?)

  def expired_api_tokens = api_tokens.filter(&:expired?)

  def expired_unfolded? = @unfold_expired || valid_api_tokens.empty?

  def rows(api_tokens) = api_tokens.map { Profile::APITokenComponent.new(api_token: it) }
end
