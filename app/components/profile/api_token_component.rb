# frozen_string_literal: true

class Profile::APITokenComponent < ApplicationComponent
  LISTED_PROCEDURES_MAX = 3

  def initialize(api_token:)
    @api_token = api_token
  end

  private

  def name_id = dom_id(@api_token, :name)

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
    if @api_token.authorized_networks.present?
      safe_join(@api_token.authorized_networks.map { tag.code("#{it}/#{it.prefix}", class: 'fr-text--xs') }, ', ')
    elsif @api_token.pending_auto_ip?
      t('.pending_ip')
    else
      tag.span(t('.no_filtering'), class: 'fr-badge fr-badge--sm fr-badge--warning')
    end
  end

  def procedures
    return t('.all_procedures') if @api_token.full_access?

    listed = if procedure_ids.size.between?(1, LISTED_PROCEDURES_MAX)
      safe_join(procedure_links, ', ')
    else
      t('.procedures_count', count: procedure_ids.size)
    end

    @api_token.follows_clones? ? t('.with_clones_html', procedures: listed, count: procedure_ids.size) : listed
  end

  def procedure_links
    Procedure.where(id: procedure_ids).order(:libelle).pluck(:id, :libelle).map do |id, libelle|
      link_to t('.procedure', libelle:, id:), admin_procedure_path(id)
    end
  end

  def procedure_ids = @procedure_ids ||= @api_token.procedure_ids

  def duplicate_button(primary:)
    button_to t('.duplicate'),
      nom_admin_api_tokens_path,
      params: { duplicate: @api_token.id },
      form: { data: { turbo: false } },
      class: class_names('fr-btn fr-btn--sm fr-btn--icon-left fr-icon-file-add-line', 'fr-btn--secondary': primary, 'fr-btn--tertiary': !primary),
      aria: { label: t('.duplicate_label', name: @api_token.name) }
  end
end
