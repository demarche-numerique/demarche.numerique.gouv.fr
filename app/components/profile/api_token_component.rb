# frozen_string_literal: true

class Profile::APITokenComponent < ApplicationComponent
  def initialize(api_token:)
    @api_token = api_token
  end

  private

  def recently_used?
    @api_token.last_used_at&.> 2.weeks.ago
  end

  def autorizations
    right = @api_token.write_access? ? 'lecture et écriture sur' : 'lecture seule sur'
    scope = @api_token.full_access? ? 'toutes les démarches' : @api_token.procedures.map(&:libelle).join(', ')
    sanitize("#{right} #{tag.b(scope)}")
  end

  def network_filtering
    if @api_token.authorized_networks.present?
      "filtrage : #{@api_token.authorized_networks_for_ui}"
    elsif @api_token.pending_auto_ip?
      tag.span('en attente de détection IP (1er appel)', class: 'fr-badge fr-badge--sm fr-badge--info')
    else
      tag.span('aucun filtrage réseau', class: 'fr-text-default--warning')
    end
  end

  def use_and_expiration
    use = @api_token.last_used_at.present? ? "utilisé il y a #{time_ago_in_words(@api_token.last_used_at)} - " : ""
    expiration = @api_token.expires_at.present? ? "valable jusquʼau #{l(@api_token.expires_at, format: :long)}" : "valable indéfiniment"

    "#{use} #{expiration}"
  end
end
