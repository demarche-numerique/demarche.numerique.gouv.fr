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
    @api_tokens ||= current_administrateur.api_tokens.includes(:transfer_recipient).order(created_at: :desc).to_a
  end

  def valid_api_tokens = api_tokens.reject(&:expired?)

  def expired_api_tokens = api_tokens.filter(&:expired?)

  def expired_unfolded? = @unfold_expired || valid_api_tokens.empty?

  def offered_api_tokens
    current_administrateur.offered_api_tokens.includes(:administrateur).filter(&:transferable?)
  end

  def shared_api_tokens
    @shared_api_tokens ||= APIToken.visible_to(current_administrateur).includes(:administrateur).order(:name).to_a
  end

  def rows(api_tokens) = api_tokens.map { Profile::APITokenComponent.new(api_token: it) }

  def shared_rows
    reader_procedure_ids = current_administrateur.procedure_ids_without_support
    shared_api_tokens.map { Profile::SharedAPITokenComponent.new(api_token: it, reader_procedure_ids:) }
  end
end
