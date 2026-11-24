# frozen_string_literal: true

class Profile::APITokenComponent < ApplicationComponent
  LISTED_MAX = 3
  # Past this length, number included, a procedure title may no longer fit on the two lines
  # its column gives it in the narrowest table (see profil.scss), when written in capitals.
  TITLE_SHOWN_MAX = 45

  def initialize(api_token:)
    @api_token = api_token
  end

  def details
    return if !folded?

    Profile::APITokenDetailsComponent.new(
      id: details_id,
      name: @api_token.name,
      networks: all_networks,
      summary: procedures_summary,
      procedures: named_procedures
    )
  end

  private

  def details_id = dom_id(@api_token, :details)

  def folded? = networks_folded? || procedures_folded? || title_cut?

  def networks_folded? = network_cidrs.size > LISTED_MAX

  def procedures_folded? = named_procedure_ids.size > LISTED_MAX

  def procedures_listed? = named_procedure_ids.size.between?(1, LISTED_MAX)

  def title_cut? = procedures_listed? && named_procedures.any? { |id, libelle| "#{t('.procedure_number', id:)} #{libelle}".size > TITLE_SHOWN_MAX }

  def details_button
    tag.button(t('.details'),
      type: 'button',
      class: 'fr-link fr-link--sm',
      aria: { controls: details_id, haspopup: 'dialog', label: t('.details_label', **label_args) },
      data: { fr_opened: 'false' })
  end

  def subtitle
    t('.transfer_offered', email: @api_token.transfer_recipient.email) if @api_token.transfer_recipient.present? && @api_token.transferable?
  end

  def label_args = { name: @api_token.name }

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
    @api_token.expires_at.present? ? l(@api_token.expires_at, format: :short) : t('.never_expires')
  end

  def expiring_soon_badge
    return if !@api_token.expiring_soon?

    tag.span(t('.expires_in', count: (@api_token.expires_at - Date.current).to_i), class: 'fr-badge fr-badge--sm fr-badge--warning')
  end

  def networks
    if network_cidrs.any?
      raw_list(network_cidrs.first(LISTED_MAX).map { tag.code(it) }, (t('.more_networks', count: network_cidrs.size - LISTED_MAX) if networks_folded?))
    elsif @api_token.expired?
      line(t('.no_network'))
    elsif @api_token.pending_auto_ip?
      line(t('.pending_ip'))
    else
      tag.span(t('.no_filtering'), class: 'fr-badge fr-badge--sm fr-badge--warning')
    end
  end

  def network_cidrs = @network_cidrs ||= @api_token.authorized_cidrs

  def all_networks
    network_cidrs.any? ? tag.ul(safe_join(network_cidrs.map { tag.li(tag.code(it)) })) : networks
  end

  def procedures
    return line(procedures_summary) if !procedures_listed?

    raw_list(procedure_items, procedures_note)
  end

  def procedures_summary = safe_join([procedures_count, procedures_note].compact, ' ')

  def procedures_count = @api_token.full_access? ? t('.all_procedures') : t('.procedures_count', count: named_procedure_ids.size)

  def procedures_note = clones

  def clones
    t('.with_clones', count: procedure_ids.size) if @api_token.follows_clones? && named_procedure_ids.any?
  end

  def procedure_items
    named_procedures.map do |id, libelle|
      tag.span(safe_join([tag.span(t('.procedure_number', id:), class: 'fr-text-mention--grey'), link_to(libelle, admin_procedure_path(id))], ' '), class: 'api-token-procedure')
    end
  end

  def line(text) = tag.p(text, class: 'fr-text--sm fr-my-0')

  def raw_list(items, note = nil)
    list = tag.ul(safe_join(items.map { tag.li(it) }), class: 'fr-raw-list fr-text--sm fr-my-0')
    note ? safe_join([list, line(note)]) : list
  end

  def named_procedures = @named_procedures ||= Procedure.where(id: named_procedure_ids).order(:libelle).pluck(:id, :libelle)

  def procedure_ids = @procedure_ids ||= @api_token.procedure_ids

  def named_procedure_ids = @api_token.full_access? ? [] : procedure_ids

  def actions = [(edit_link if !@api_token.expired?), duplicate_button, destroy_link].compact

  def edit_link
    link_to t('.edit'),
      edit_admin_api_token_path(@api_token),
      class: 'fr-btn fr-btn--tertiary-no-outline fr-icon-pencil-line',
      aria: { label: t('.edit_label', name: @api_token.name) }
  end

  def duplicate_button
    button_to t('.duplicate'),
      nom_admin_api_tokens_path,
      params: { duplicate: @api_token.id },
      form: { data: { turbo: false } },
      class: 'fr-btn fr-btn--tertiary-no-outline fr-icon-file-add-line',
      aria: { label: t('.duplicate_label', **label_args) }
  end

  def destroy_link
    link_to t('.destroy'),
      admin_api_token_path(@api_token),
      class: 'fr-btn fr-btn--tertiary-no-outline fr-icon-delete-line',
      aria: { label: t('.destroy_label', name: @api_token.name) },
      data: { turbo_method: :delete, turbo_confirm: t('.destroy_confirm', name: @api_token.name) }
  end
end
