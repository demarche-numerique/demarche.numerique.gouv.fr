# frozen_string_literal: true

# The card of a type de champ in the editor: its form, its condition and what
# moves or removes it. The list item around it is NodeComponent.
class TypesDeChampEditor::ChampComponent < ApplicationComponent
  attr_reader :type_de_champ

  # a type de champ of the draft, laid out: it knows what it sits with
  def initialize(type_de_champ:, focused: false, errors: '')
    @type_de_champ = type_de_champ
    @focused = focused
    @errors = errors
  end

  private

  delegate :libelle_configurable?, :description_configurable?, :revision, to: :type_de_champ
  delegate :procedure, to: :revision

  def siblings
    @siblings ||= type_de_champ.flat_siblings
  end

  def index
    @index ||= siblings.index(type_de_champ)
  end

  def mandatory_configurable?
    type_de_champ.fillable? && !type_de_champ.must_be_mandatory? && !type_de_champ.cannot_be_mandatory?
  end

  def lock_explanation
    case type_de_champ.type_champ_lock_reason
    when :used_by_routing_rules
      tag.span(t(".used_for_routing_html", link: link_to(t(".routing_link"), admin_procedure_groupe_instructeurs_path(revision.procedure_id, anchor: "routing-rules"))))
    when :used_by_referentiel_urls
      tag.span(t(".used_for_referentiel_html", link: referentiel_link))
    when :used_by_ineligibilite_rules
      tag.span(t(".used_for_ineligibilite_html", link: link_to(t(".ineligibilite_link"), edit_admin_procedure_ineligibilite_rules_path(revision.procedure_id))))
    end
  end

  def referentiel_link
    referentiel_type_de_champ = type_de_champ.referentiel_type_de_champ_using_url
    return t(".referentiel_link") if referentiel_type_de_champ.nil?

    link_to(t(".referentiel_link"), edit_admin_procedure_referentiel_path(revision.procedure_id, referentiel_type_de_champ.stable_id), data: { turbo: false })
  end

  def type_de_champ_path
    admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id)
  end

  def form_options
    {
      url: admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
      html: { multipart: true, id: nil, class: 'form width-100' },
    }
  end

  def move_button_options(direction)
    {
      type: 'button',
      data: { action: 'type-de-champ-editor#onMoveButtonClick', type_de_champ_editor_direction_param: direction },
      title: direction == :up ? t(".move_up_title") : t(".move_down_title"),
    }
  end

  def input_autofocus
    @focused ? { controller: 'autofocus' } : nil
  end

  def notice_explicative_options
    {
      attached_file: type_de_champ.notice_explicative,
      auto_attach_url: helpers.auto_attach_url(type_de_champ, procedure_id: procedure.id),
      view_as: :download,
    }
  end

  def options_for_character_limit
    options = [[t('.character_limit.unlimited'), nil]]

    (400..900).step(100).to_a.concat((1000..10000).step(1000).to_a).each do |limit|
      options << [t('.character_limit.limit', limit: limit.to_fs(:delimited)), limit]
    end

    options
  end

  def prefill_with_france_connect_information_locked_by_sibling?
    return false if type_de_champ.date? && type_de_champ.prefill_with_france_connect_information?

    revision.type_de_champs.any? do |tdc|
      tdc.date? && tdc.prefill_with_france_connect_information? && tdc.id != type_de_champ.id
    end
  end

  def turbo_confirm
    if (prefilled_by = type_de_champ.prefilled_by_type_de_champ)
      t(".confirm_prefilled_removal", libelle: prefilled_by.libelle)
    else
      t(".confirm_removal")
    end
  end
end
