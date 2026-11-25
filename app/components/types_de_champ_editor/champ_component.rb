# frozen_string_literal: true

# The card of a type de champ in the editor: its form, its condition and what
# moves or removes it. What it holds is not in there (NodeComponent): the card
# is rendered again on its own.
class TypesDeChampEditor::ChampComponent < ApplicationComponent
  attr_reader :type_de_champ

  # a type de champ of the draft, laid out: it knows what it sits with
  def initialize(type_de_champ:, focused: false, errors: '')
    @type_de_champ = type_de_champ
    @focused = focused
    @errors = errors
  end

  OPPOSITE_MOVES = { move_up: :move_down, move_down: :move_up, move_in: :move_out, move_out: :move_in }.freeze

  # What an edit made from the card gives the focus back to: its button when
  # the card still shows it, the opposite move otherwise, or the libellé.
  def focus_after(edit)
    button = [edit, OPPOSITE_MOVES[edit]].compact.find { edit?(it) }

    dom_id(type_de_champ, button ? :"#{button}_button" : :libelle)
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

  def html_options
    {
      id: dom_id(type_de_champ, :editor_error),
      class: 'type-de-champ-container',
      data: { controller: 'type-de-champ-editor' },
    }
  end

  def form_options
    {
      url: admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
      html: { multipart: true, id: nil, class: 'form width-100' },
    }
  end

  # a move leaving it where it is has no button
  def move?(move)
    case move
    when :move_up then type_de_champ.previous_sibling.present? || in_section?
    when :move_down then type_de_champ.next_sibling.present? || in_section?
    when :move_in then type_de_champ.previous_sibling&.header_section?
    when :move_out then in_section?
    end
  end

  def in_section? = type_de_champ.parent&.header_section?

  MOVE_ICONS = { move_up: 'fr-icon-arrow-up-line', move_down: 'fr-icon-arrow-down-line', move_in: 'fr-icon-arrow-right-line', move_out: 'fr-icon-arrow-left-line' }.freeze

  def move_button_options(move)
    edit_button_options(move).merge(
      title: t(".#{move}_title"),
      class: class_names('fr-btn fr-btn--tertiary-no-outline', MOVE_ICONS.fetch(move), hidden: !move?(move))
    )
  end

  def edit_button_options(edit)
    {
      type: 'button',
      id: dom_id(type_de_champ, :"#{edit}_button"),
      data: {
        action: 'type-de-champ-editor#onEditButtonClick',
        type_de_champ_editor_url_param: url_for([edit, :admin, procedure, :type_de_champ, { stable_id: type_de_champ.stable_id }]),
      },
    }
  end

  # a header section followed by anything but another one
  def takes_following_siblings?
    type_de_champ.header_section? && type_de_champ.next_sibling.present? && !type_de_champ.next_sibling.header_section?
  end

  # the button of an edit leaving everything where it is stays hidden
  def edit?(edit) = edit == :take_following_siblings ? takes_following_siblings? : move?(edit)

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
