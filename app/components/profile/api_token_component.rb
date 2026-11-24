# frozen_string_literal: true

class Profile::APITokenComponent < ApplicationComponent
  LISTED_MAX = 3

  def initialize(api_token:)
    @api_token = api_token
  end

  def details
    return if !folded?

    Profile::APITokenDetailsComponent.new(
      id: details_id,
      name: @api_token.name,
      networks: all_networks,
      summary: procedures,
      procedures: named_procedures
    )
  end

  private

  def name_id = dom_id(@api_token, :name)

  def details_id = dom_id(@api_token, :details)

  def folded? = networks_folded? || procedures_folded?

  def networks_folded? = network_cidrs.size > LISTED_MAX

  def procedures_folded? = named_procedure_ids.size > LISTED_MAX

  def details_button
    tag.button(t('.details'),
      type: 'button',
      class: 'fr-btn fr-btn--tertiary-no-outline fr-btn--sm fr-my-n1v',
      aria: { controls: details_id, haspopup: 'dialog', label: t('.details_label', name: @api_token.name) },
      data: { fr_opened: 'false' })
  end

  def prefix = tag.code(@api_token.prefix, class: 'fr-text--xs fr-text-default--grey')

  def access = @api_token.write_access? ? t('.read_write') : t('.read_only')

  def last_use
    if @api_token.last_used_at.present?
      t('.used_ago', time: time_ago_in_words(@api_token.last_used_at, scope: :'datetime.distance_in_words.short'))
    else
      t('.never_used')
    end
  end

  def expiration
    @api_token.expires_at.present? ? l(@api_token.expires_at, format: :long) : t('.never_expires')
  end

  def expiration_badge
    if @api_token.expired?
      tag.span(t('.expired'), class: 'fr-badge fr-badge--sm fr-badge--error')
    elsif @api_token.expiring_soon?
      tag.span(t('.expiring_soon'), class: 'fr-badge fr-badge--sm fr-badge--warning')
    end
  end

  def networks
    if networks_folded?
      t('.more_networks_html', networks: listed_networks(network_cidrs.first(LISTED_MAX)), count: network_cidrs.size - LISTED_MAX)
    elsif network_cidrs.any?
      listed_networks(network_cidrs)
    elsif @api_token.pending_auto_ip?
      t('.pending_ip')
    else
      tag.span(t('.no_filtering'), class: 'fr-badge fr-badge--sm fr-badge--warning')
    end
  end

  def network_cidrs = @network_cidrs ||= @api_token.authorized_cidrs

  def listed_networks(cidrs) = safe_join(cidrs.map { tag.code(it, class: 'fr-text--xs') }, ', ')

  def all_networks
    network_cidrs.any? ? tag.ul(safe_join(network_cidrs.map { tag.li(tag.code(it)) })) : networks
  end

  def procedures
    return t('.all_procedures') if @api_token.full_access?

    @procedures ||= begin
      listed = if named_procedure_ids.size.between?(1, LISTED_MAX)
        safe_join(procedure_links, ', ')
      else
        t('.procedures_count', count: named_procedure_ids.size)
      end

      @api_token.follows_clones? ? t('.with_clones_html', procedures: listed, count: named_procedure_ids.size) : listed
    end
  end

  def procedure_links
    named_procedures.map { |id, libelle| link_to t('.procedure', libelle:, id:), admin_procedure_path(id) }
  end

  def named_procedures = @named_procedures ||= Procedure.where(id: named_procedure_ids).order(:libelle).pluck(:id, :libelle)

  def named_procedure_ids = @named_procedure_ids ||= @api_token.full_access? ? [] : @api_token.procedure_ids

  def duplicate_button(primary:)
    button_to t('.duplicate'),
      nom_admin_api_tokens_path,
      params: { duplicate: @api_token.id },
      form: { data: { turbo: false } },
      class: class_names('fr-btn fr-btn--sm fr-btn--icon-left fr-icon-file-add-line', 'fr-btn--secondary': primary, 'fr-btn--tertiary': !primary),
      aria: { label: t('.duplicate_label', name: @api_token.name) }
  end
end
