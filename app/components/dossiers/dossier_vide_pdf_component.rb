# frozen_string_literal: true

class Dossiers::DossierVidePdfComponent < ApplicationComponent
  attr_reader :revision, :procedure

  def initialize(revision:)
    @revision = revision
    @procedure = revision.procedure
    @annexes = []
  end

  private

  def types_de_champ_public = revision.root_types_de_champ_public

  # Populated while rendering champs (see boxed_field_with_annex); read by the
  # template after the form to append the "Annexes" pages.
  def annexes = @annexes

  def organisation = procedure.organisation_name.presence || "En attente de saisie"

  def mailing_instruction
    service = procedure.service
    return if service.blank?

    ["À envoyer à #{service.nom}", service.adresse.to_s.squish.presence].compact.join(' - ')
  end

  # Empty field to fill in by hand: a bordered box (meaning carried by the preceding label)
  def fillable_box(height: :line)
    tag.div('', class: "box box--#{height}", aria: { hidden: true })
  end

  # Label / fillable area pair
  def fillable_field(label)
    tag.div(class: 'field-pair') do
      safe_join([tag.dt(label), tag.dd(fillable_box)])
    end
  end

  REPETITION_OCCURRENCES = 3

  def render_champ(type_de_champ)
    case type_de_champ.type_champ
    when TypeDeChamp.type_champs.fetch(:header_section)
      safe_join([header_section_heading(type_de_champ), description(type_de_champ)].compact)
    when TypeDeChamp.type_champs.fetch(:explication)
      safe_join([libelle(type_de_champ), tag.div(simple_format(type_de_champ.description), class: 'explication')].compact)
    when TypeDeChamp.type_champs.fetch(:piece_justificative)
      safe_join([
        tag.p('Pièce justificative à joindre en complément du dossier', class: 'label'),
        checkboxes([type_de_champ.libelle]),
        description(type_de_champ),
      ].compact)
    when TypeDeChamp.type_champs.fetch(:yes_no), TypeDeChamp.type_champs.fetch(:checkbox)
      field_with_options(type_de_champ, ['Oui', 'Non'], explanation: 'Cochez la mention applicable')
    when TypeDeChamp.type_champs.fetch(:civilite)
      field_with_options(type_de_champ, [Individual::GENDER_FEMALE, Individual::GENDER_MALE])
    when TypeDeChamp.type_champs.fetch(:drop_down_list)
      if type_de_champ.drop_down_advanced?
        libelle_and_box(type_de_champ)
      elsif too_many_options?(type_de_champ)
        boxed_field_with_annex(type_de_champ, multiple: false)
      else
        field_with_options(type_de_champ, type_de_champ.drop_down_options, explanation: 'Cochez la mention applicable, une seule valeur possible')
      end
    when TypeDeChamp.type_champs.fetch(:multiple_drop_down_list)
      if type_de_champ.drop_down_advanced?
        libelle_and_box(type_de_champ)
      elsif too_many_options?(type_de_champ)
        boxed_field_with_annex(type_de_champ, multiple: true)
      else
        field_with_options(type_de_champ, type_de_champ.drop_down_options, explanation: 'Cochez la mention applicable, plusieurs valeurs possibles')
      end
    when TypeDeChamp.type_champs.fetch(:linked_drop_down_list)
      linked_field(type_de_champ)
    when TypeDeChamp.type_champs.fetch(:siret)
      establishment(type_de_champ.libelle)
    when TypeDeChamp.type_champs.fetch(:repetition)
      repetition(type_de_champ)
    else
      libelle_and_box(type_de_champ)
    end
  end

  # Maps the section level to a heading below the "Formulaire" <h2>, mirroring the
  # web form (level 1 → h3), so the PDF/UA tag tree preserves the document outline.
  def header_section_heading(type_de_champ)
    level = [type_de_champ.level_for_revision(revision) + 2, 6].min
    tag.public_send("h#{level}", type_de_champ.libelle)
  end

  # Label followed, for a conditional champ, by the "À remplir si …" instruction.
  def libelle(type_de_champ)
    safe_join([tag.p(type_de_champ.libelle, class: 'label'), condition_instruction(type_de_champ)].compact)
  end

  # 'champ champ--conditional' shades a conditional field so the applicant sees
  # the instruction and the box belong together.
  def champ_css_class(type_de_champ)
    displayable_condition?(type_de_champ) ? 'champ champ--conditional' : 'champ'
  end

  def condition_instruction(type_de_champ)
    return unless displayable_condition?(type_de_champ)

    tag.p("À remplir si #{humanize_condition(type_de_champ.condition)}", class: 'condition')
  end

  # An admin editing a procedure can persist an unfinished condition row
  # (Logic::EmptyOperator with Logic::Empty members); such a condition carries no
  # meaning and has no operator label, so we never surface it in the PDF.
  def displayable_condition?(type_de_champ)
    condition = type_de_champ.condition
    condition.present? && condition.terms.none? { it.is_a?(Logic::EmptyOperator) || it.is_a?(Logic::Empty) }
  end

  # Reuses the operator labels from the admin condition editor (logic.operators),
  # falling back to the technical form (Logic#to_s) for anything we do not phrase.
  def humanize_condition(term)
    case term
    when Logic::NAryOperator
      term.operands.map { humanize_condition(it) }.join(" #{operator_label(term)} ")
    when Logic::BinaryOperator
      "« #{term.left.to_s(condition_type_de_champs)} » #{operator_label(term)} « #{condition_value(term)} »"
    else
      term.to_s(condition_type_de_champs)
    end
  end

  def operator_label(term) = t(term.class.name, scope: 'logic.operators').sub(/\A./, &:downcase)

  # Human label of the compared value (e.g. a region code → its name), taken from
  # the referenced champ's options; falls back to the raw value.
  def condition_value(term)
    raw = term.right.is_a?(Logic::Constant) ? term.right.value : nil
    options = term.left.is_a?(Logic::ChampValue) ? term.left.options(condition_type_de_champs, term.class.name) : nil
    options&.find { |(_label, value)| value == raw }&.first || term.right.to_s(condition_type_de_champs)
  rescue StandardError
    term.right.to_s(condition_type_de_champs)
  end

  def condition_type_de_champs = revision.flat_types_de_champ_public

  def description(type_de_champ)
    return if type_de_champ.description.blank?

    tag.div(simple_format(type_de_champ.description), class: 'description')
  end

  # Renders admin-authored rich text (bold, italic, links, line breaks) exactly
  # like the web form does, so the printed form matches the on-screen one.
  def simple_format(text) = render(SimpleFormatComponent.new(text, allow_a: true))

  def libelle_and_box(type_de_champ)
    safe_join([libelle(type_de_champ), description(type_de_champ), fillable_box(height: :block)].compact)
  end

  # A decorative checkbox (aria-hidden) followed by the real meaning-bearing label
  def checkbox(label)
    tag.span(class: 'option') do
      safe_join([tag.span('', class: 'checkbox', aria: { hidden: true }), tag.span(label)])
    end
  end

  def checkboxes(labels)
    tag.ul(class: 'options') { safe_join(labels.map { |l| tag.li(checkbox(option_label(l))) }) }
  end

  def field_with_options(type_de_champ, options, explanation: nil)
    explanation_tag = tag.p(explanation, class: 'explanation') if explanation
    safe_join([libelle(type_de_champ), description(type_de_champ), explanation_tag, checkboxes(options)].compact)
  end

  def linked_field(type_de_champ)
    items = type_de_champ.primary_options.compact_blank.flat_map do |primary|
      secondaries = type_de_champ.secondary_options[primary].to_a.compact_blank
      [tag.li(checkbox(primary))] +
        secondaries.map { |s| tag.li(checkbox(s), class: 'secondary') }
    end
    safe_join([libelle(type_de_champ), tag.ul(safe_join(items), class: 'options')])
  end

  def establishment(label)
    safe_join([
      tag.p(label, class: 'label'),
      fillable_field('SIRET'),
      fillable_field('Dénomination'),
      fillable_field('Forme juridique'),
    ])
  end

  def repetition(type_de_champ)
    children = revision.children_of(type_de_champ)
    occurrences = Array.new(REPETITION_OCCURRENCES) do
      safe_join(children.map { |child| tag.section(render_champ(child), class: champ_css_class(child)) })
    end
    safe_join([libelle(type_de_champ), *occurrences])
  end

  # drop_down_options may contain Strings or [text, value] pairs
  def option_label(option) = option.is_a?(Array) ? option.first : option

  # Past this many options the web form switches to a searchable combobox, so
  # listing every option inline would span pages: keep a write-in box in the
  # form and move the full list to an annex at the end of the document.
  def too_many_options?(type_de_champ)
    type_de_champ.drop_down_options.size >= Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE
  end

  # Write-in box referencing the annex that lists every option. The annex is a
  # reference the applicant reads to fill in the box, not something to print/tick.
  def boxed_field_with_annex(type_de_champ, multiple:)
    number = register_annex(type_de_champ)
    instruction = if multiple
      'Renseignez les mentions applicables, plusieurs valeurs possibles'
    else
      'Renseignez la mention applicable, une seule valeur possible'
    end
    reference = tag.p("La liste complète des options figure en Annexe #{number}. #{instruction}", class: 'explanation')
    safe_join([libelle(type_de_champ), description(type_de_champ), reference, fillable_box(height: :block)].compact)
  end

  # Records the champ (once, even across repetition occurrences) and returns its
  # 1-based annex number, following document order.
  def register_annex(type_de_champ)
    @annexes << type_de_champ unless @annexes.include?(type_de_champ)
    @annexes.index(type_de_champ) + 1
  end

  # A plain reference list (no checkboxes): the applicant reads it to fill in the
  # form and can skip printing it when it is long.
  def render_annex(type_de_champ, number)
    items = type_de_champ.drop_down_options.map { |option| tag.li(option_label(option)) }
    safe_join([
      tag.h3("Annexe #{number} : #{type_de_champ.libelle}"),
      tag.ul(safe_join(items), class: 'annex-options'),
    ])
  end
end
