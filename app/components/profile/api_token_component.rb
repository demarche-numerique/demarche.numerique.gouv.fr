# frozen_string_literal: true

class Profile::APITokenComponent < ApplicationComponent
  LISTED_PROCEDURES_MAX = 3

  def initialize(api_token:)
    @api_token = api_token
  end

  private

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
    if @api_token.authorized_networks.present?
      raw_list(@api_token.authorized_cidrs.map { tag.code(it) })
    elsif @api_token.expired?
      line(t('.no_network'))
    elsif @api_token.pending_auto_ip?
      line(t('.pending_ip'))
    else
      tag.span(t('.no_filtering'), class: 'fr-badge fr-badge--sm fr-badge--warning')
    end
  end

  def procedures
    return line(t('.all_procedures')) if @api_token.full_access?

    if procedure_ids.size.between?(1, LISTED_PROCEDURES_MAX)
      raw_list(procedure_items, clones)
    else
      line(safe_join([t('.procedures_count', count: procedure_ids.size), clones].compact, ' '))
    end
  end

  def clones
    t('.with_clones', count: procedure_ids.size) if @api_token.follows_clones? && procedure_ids.any?
  end

  def procedure_items
    Procedure.where(id: procedure_ids).order(:libelle).pluck(:id, :libelle).map do |id, libelle|
      safe_join([tag.span(t('.procedure_number', id:), class: 'fr-text-mention--grey'), link_to(libelle, admin_procedure_path(id))], ' ')
    end
  end

  def line(text) = tag.p(text, class: 'fr-text--sm fr-my-0')

  def raw_list(items, note = nil)
    list = tag.ul(safe_join(items.map { tag.li(it) }), class: 'fr-raw-list fr-text--sm fr-my-0')
    note ? safe_join([list, line(note)]) : list
  end

  def procedure_ids = @procedure_ids ||= @api_token.procedure_ids

  def duplicate_button
    button_to t('.duplicate'),
      nom_admin_api_tokens_path,
      params: { duplicate: @api_token.id },
      form: { data: { turbo: false } },
      class: 'fr-btn fr-btn--tertiary-no-outline fr-icon-file-add-line',
      aria: { label: t('.duplicate_label', name: @api_token.name) }
  end
end
