# frozen_string_literal: true

# Payload of the empty printable form PDF (lib/typst/dossier_vide.typ,
# rendered by TypstService): already-localized strings and a small
# discriminated union of champ blocks - layout lives in the template.
# Port of the retired Dossiers::DossierVidePdfComponent.
class DossierVidePayload
  # Past this volume a list is not a hand-written enumeration any more but a
  # whole dataset pasted in (every commune, every school): printing it would
  # run to hundreds of pages, so we point to the online form instead.
  # Calibrated above the p99 of production lists.
  MAX_PRINTABLE_OPTIONS = 5_000

  # Second threshold: past 20 options the list moves to an annex, past
  # MAX_PRINTABLE_OPTIONS it is not printed at all.
  REPETITION_OCCURRENCES = 3

  CHOICE_LIST_TYPES = [
    TypeDeChamp.type_champs.fetch(:drop_down_list),
    TypeDeChamp.type_champs.fetch(:multiple_drop_down_list),
    TypeDeChamp.type_champs.fetch(:linked_drop_down_list),
  ].freeze

  attr_reader :revision, :procedure

  def initialize(revision)
    @revision = revision
    @procedure = revision.procedure
    @annexes = []
    # Level of the last heading emitted; the template's h2 "Formulaire"
    # precedes the champs.
    @heading_level = 2
  end

  def to_h
    champs = revision.public_root_type_de_champs.map { champ_block(it) }

    {
      # Pinned: every string of this document is authored in French whatever
      # the user's UI locale (the attestation payload, by contrast, is
      # I18n-translated and keeps the user locale).
      lang: 'fr',
      title: procedure.libelle,
      logo: { path: '/app/assets/images/header/logo-ds-wide.png', alt: 'Logo de l’administration' },
      organisation: procedure.organisation_name.presence || 'En attente de saisie',
      identity_fields:,
      presentation: rich_text(procedure.description),
      mailing: mailing_instruction,
      champs:,
      annexes: @annexes.each_with_index.map do |type_de_champ, index|
        {
          title: "Annexe #{index + 1} : #{type_de_champ.libelle}",
          options: type_de_champ.drop_down_options.map { option_label(it) },
        }
      end,
    }
  end

  private

  def identity_fields
    if procedure.for_individual?
      ['Email', 'Civilité', 'Nom', 'Prénom'].tap { it << 'Date de naissance' if procedure.ask_birthday? }
    else
      ['Email', 'SIRET', 'Dénomination', 'Forme juridique']
    end
  end

  def mailing_instruction
    service = procedure.service
    return if service.blank?

    ["À envoyer à #{service.nom}", service.adresse.to_s.squish.presence].compact.join(' - ')
  end

  def champ_block(type_de_champ)
    base = {
      libelle: type_de_champ.libelle,
      condition: condition_instruction(type_de_champ),
      conditional: displayable_condition?(type_de_champ),
    }

    return online_reference_block(type_de_champ, base) if too_many_options_to_print?(type_de_champ)

    case type_de_champ.type_champ
    when TypeDeChamp.type_champs.fetch(:header_section)
      base.merge(type: 'heading', **heading_fields(type_de_champ), description: rich_text(type_de_champ.description))
    when TypeDeChamp.type_champs.fetch(:explication)
      base.merge(type: 'explication', text: rich_text(type_de_champ.description))
    when TypeDeChamp.type_champs.fetch(:piece_justificative)
      base.merge(
        type: 'piece_justificative',
        label: 'Pièce justificative à joindre en complément du dossier',
        option: type_de_champ.libelle,
        description: rich_text(type_de_champ.description),
        condition: nil
      )
    when TypeDeChamp.type_champs.fetch(:yes_no), TypeDeChamp.type_champs.fetch(:checkbox)
      checkboxes_block(type_de_champ, base, ['Oui', 'Non'], explanation: 'Cochez la mention applicable')
    when TypeDeChamp.type_champs.fetch(:civilite)
      checkboxes_block(type_de_champ, base, [Individual::GENDER_FEMALE, Individual::GENDER_MALE])
    when TypeDeChamp.type_champs.fetch(:drop_down_list)
      if type_de_champ.drop_down_advanced?
        box_block(type_de_champ, base)
      elsif too_many_options?(type_de_champ)
        annex_reference_block(type_de_champ, base, multiple: false)
      else
        checkboxes_block(type_de_champ, base, type_de_champ.drop_down_options, explanation: 'Cochez la mention applicable, une seule valeur possible')
      end
    when TypeDeChamp.type_champs.fetch(:multiple_drop_down_list)
      if type_de_champ.drop_down_advanced?
        box_block(type_de_champ, base)
      elsif too_many_options?(type_de_champ)
        annex_reference_block(type_de_champ, base, multiple: true)
      else
        checkboxes_block(type_de_champ, base, type_de_champ.drop_down_options, explanation: 'Cochez la mention applicable, plusieurs valeurs possibles')
      end
    when TypeDeChamp.type_champs.fetch(:linked_drop_down_list)
      base.merge(type: 'checkboxes', options: linked_options(type_de_champ))
    when TypeDeChamp.type_champs.fetch(:siret)
      base.merge(type: 'establishment')
    when TypeDeChamp.type_champs.fetch(:repetition)
      children = revision.children_of(type_de_champ)
      occurrence = children.map { champ_block(it) }
      base.merge(type: 'repetition', occurrences: Array.new(REPETITION_OCCURRENCES) { occurrence })
    else
      box_block(type_de_champ, base)
    end
  end

  def checkboxes_block(type_de_champ, base, options, explanation: nil)
    base.merge(
      type: 'checkboxes',
      description: rich_text(type_de_champ.description),
      explanation:,
      options: options.map { { label: option_label(it) } }
    )
  end

  def box_block(type_de_champ, base, explanation: nil)
    base.merge(
      type: 'box',
      description: rich_text(type_de_champ.description),
      explanation:,
      box: 'block'
    )
  end

  def linked_options(type_de_champ)
    type_de_champ.primary_options.compact_blank.flat_map do |primary|
      secondaries = type_de_champ.secondary_options[primary].to_a.compact_blank
      [{ label: primary }] + secondaries.map { { label: it, secondary: true } }
    end
  end

  # Write-in box referencing the online form: the applicant fills the box from
  # the searchable list on the website rather than from an unprintable annex.
  def online_reference_block(type_de_champ, base)
    url = Rails.application.routes.url_helpers.commencer_url(procedure.path)
    count = ApplicationController.helpers.number_with_delimiter(type_de_champ.drop_down_options.size)
    box_block(
      type_de_champ,
      base,
      explanation: "Cette liste comporte #{count} valeurs : elle n’est pas reproduite ici. " \
                   "Renseignez votre réponse en vous aidant du formulaire en ligne : #{url}"
    )
  end

  # Write-in box referencing the annex that lists every option.
  def annex_reference_block(type_de_champ, base, multiple:)
    number = register_annex(type_de_champ)
    instruction = if multiple
      'Renseignez les mentions applicables, plusieurs valeurs possibles'
    else
      'Renseignez la mention applicable, une seule valeur possible'
    end
    box_block(type_de_champ, base, explanation: "La liste complète des options figure en Annexe #{number}. #{instruction}")
  end

  # Records the champ (once, even across repetition occurrences) and returns
  # its 1-based annex number, following document order.
  def register_annex(type_de_champ)
    @annexes << type_de_champ unless @annexes.include?(type_de_champ)
    @annexes.index(type_de_champ) + 1
  end

  def too_many_options?(type_de_champ)
    type_de_champ.drop_down_options.size >= Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE
  end

  def too_many_options_to_print?(type_de_champ)
    return false if !type_de_champ.type_champ.in?(CHOICE_LIST_TYPES) || type_de_champ.drop_down_advanced?

    type_de_champ.drop_down_options.size >= MAX_PRINTABLE_OPTIONS
  end

  # PDF/UA-1 (enforced by typst, which hard-fails the compilation) rejects
  # skipped heading levels, and a revision can legitimately hold a gap:
  # HeaderSectionConsistencyValidator only runs when editing or publishing,
  # so older revisions predating it are served as they are. Clamp each
  # heading to at most one level below the previous one, capped at h6.
  def heading_level(type_de_champ)
    @heading_level = [type_de_champ.level_for_revision(revision) + 2, @heading_level + 1, 6].min
  end

  # A section whose title was cleared (TypeDeChamp does not validate the
  # libelle) keeps its description but emits no heading: typst rejects an
  # empty heading title under PDF/UA-1, and it would tell the reader nothing.
  def heading_fields(type_de_champ)
    return { level: nil, text: nil } if type_de_champ.libelle.blank?

    { level: heading_level(type_de_champ), text: type_de_champ.libelle }
  end

  def condition_instruction(type_de_champ)
    return unless displayable_condition?(type_de_champ)

    "À remplir si #{humanize_condition(type_de_champ.condition)}"
  end

  # An admin editing a procedure can persist an unfinished condition row
  # (Logic::EmptyOperator with Logic::Empty members); such a condition carries
  # no meaning and has no operator label, so we never surface it in the PDF.
  def displayable_condition?(type_de_champ)
    condition = type_de_champ.condition
    condition.present? && condition.terms.none? { it.is_a?(Logic::EmptyOperator) || it.is_a?(Logic::Empty) }
  end

  # Reuses the operator labels from the admin condition editor
  # (logic.operators), falling back to Logic#to_s for anything we do not phrase.
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

  def operator_label(term) = I18n.t(term.class.name, scope: 'logic.operators').sub(/\A./, &:downcase)

  # Human label of the compared value (e.g. a region code -> its name), taken
  # from the referenced champ's options; falls back to the raw value.
  def condition_value(term)
    raw = term.right.is_a?(Logic::Constant) ? term.right.value : nil
    options = term.left.is_a?(Logic::ChampValue) ? term.left.options(condition_type_de_champs, term.class.name) : nil
    options&.find { |(_label, value)| value == raw }&.first || term.right.to_s(condition_type_de_champs)
  rescue StandardError
    term.right.to_s(condition_type_de_champs)
  end

  # (called several times per condition term; public_flat_type_de_champs is not memoized)
  def condition_type_de_champs = @condition_type_de_champs ||= revision.public_flat_type_de_champs

  # Admin-authored Markdown as the block/inline tree the theme renders
  # (Typst::RichText), so the paper form matches the web rendering.
  def rich_text(text) = Typst::RichText.from_markdown(text)

  def option_label(option) = option.is_a?(Array) ? option.first : option
end
