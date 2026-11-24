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
      summary: legend_procedures,
      procedures: named_procedures
    )
  end

  private

  def row_id = dom_id(@api_token)

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

  def subtitle = nil

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

  def legend_procedures = @legend_procedures ||= procedures

  def procedures
    return t('.all_procedures') if @api_token.full_access?

    with_clones(listed_procedures { t('.procedures_count', count: it) })
  end

  def with_clones(procedures)
    @api_token.follows_clones? ? t('.with_clones_html', procedures:, count: procedure_ids.size) : procedures
  end

  def listed_procedures
    named_procedure_ids.size.between?(1, LISTED_MAX) ? safe_join(procedure_links, ', ') : yield(named_procedure_ids.size)
  end

  def procedure_links
    named_procedures.map { |id, libelle| link_to t('.procedure', libelle:, id:), admin_procedure_path(id) }
  end

  def named_procedures = @named_procedures ||= Procedure.where(id: named_procedure_ids).order(:libelle).pluck(:id, :libelle)

  def procedure_ids = @procedure_ids ||= @api_token.procedure_ids

  def named_procedure_ids = @api_token.full_access? ? [] : procedure_ids

  def actions
    if @api_token.expired?
      [duplicate_button(primary: true), destroy_link]
    else
      [edit_link, duplicate_button(primary: false), destroy_link]
    end
  end

  def edit_link
    link_to t('.edit'),
      edit_admin_api_token_path(@api_token),
      class: 'fr-btn fr-btn--sm fr-btn--secondary fr-btn--icon-left fr-icon-pencil-line',
      aria: { label: t('.edit_label', name: @api_token.name) }
  end

  def duplicate_button(primary:)
    button_to t('.duplicate'),
      nom_admin_api_tokens_path,
      params: { duplicate: @api_token.id },
      form: { data: { turbo: false } },
      class: class_names('fr-btn fr-btn--sm fr-btn--icon-left fr-icon-file-add-line', 'fr-btn--secondary': primary, 'fr-btn--tertiary': !primary),
      aria: { label: t('.duplicate_label', name: @api_token.name) }
  end

  def destroy_link
    link_to t('.destroy'),
      admin_api_token_path(@api_token),
      class: 'fr-btn fr-btn--sm fr-btn--tertiary fr-btn--icon-left fr-icon-delete-line',
      aria: { label: t('.destroy_label', name: @api_token.name) },
      data: { turbo_method: :delete, turbo_confirm: t('.destroy_confirm', name: @api_token.name) }
  end
end
