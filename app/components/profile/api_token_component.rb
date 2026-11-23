# frozen_string_literal: true

class Profile::APITokenComponent < ApplicationComponent
  LISTED_PROCEDURES_MAX = 3

  def initialize(api_token:)
    @api_token = api_token
  end

  private

  def recently_used?
    @api_token.last_used_at&.> 2.weeks.ago
  end

  def autorizations
    right = @api_token.write_access? ? t(".read_write_prefix") : t(".read_only_prefix")
    sanitize("#{right} #{tag.b(procedures_scope)}")
  end

  def procedures_scope
    return t(".all_procedures") if @api_token.full_access?

    procedure_ids = @api_token.procedure_ids
    procedures = if procedure_ids.size.between?(1, LISTED_PROCEDURES_MAX)
      Procedure.where(id: procedure_ids).pluck(:libelle).join(', ')
    else
      t(".procedures_count", count: procedure_ids.size)
    end

    @api_token.follows_clones? ? t(".with_clones", procedures:, count: procedure_ids.size) : procedures
  end

  def network_filtering
    if @api_token.authorized_networks.present?
      t(".network_filtering", networks: @api_token.authorized_networks_for_ui)
    elsif @api_token.pending_auto_ip?
      tag.span(t(".pending_ip"), class: 'fr-badge fr-badge--sm fr-badge--info')
    else
      tag.span(t(".no_filtering"), class: 'fr-text-default--warning')
    end
  end

  def use_and_expiration
    use = @api_token.last_used_at.present? ? t(".used_ago", time: time_ago_in_words(@api_token.last_used_at)) : ""
    expiration = @api_token.expires_at.present? ? t(".valid_until", date: l(@api_token.expires_at, format: :long)) : t(".valid_indefinitely")

    "#{use} #{expiration}"
  end

  def expiration_badge
    if @api_token.expired?
      tag.span(t(".expired"), class: 'fr-badge fr-badge--sm fr-badge--error')
    elsif @api_token.expiring_soon?
      tag.span(t(".expiring_soon"), class: 'fr-badge fr-badge--sm fr-badge--warning')
    end
  end
end
