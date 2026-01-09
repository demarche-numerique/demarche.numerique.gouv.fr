# frozen_string_literal: true

module TagsSubstitutionConcern
  extend ActiveSupport::Concern

  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TextHelper

  module TagsParser
    include Parsby::Combinators
    extend self

    def parse(io)
      doc.parse(+io) # parsby mutates the StringIO during parsing!
    end

    def self.normalize(str)
      str
        .sub(/^[[:space:]]+/, '')
        .sub(/[[:space:]]+$/, '')
        .gsub(/[[:space:]]/, ' ')
        .gsub('&nbsp;', ' ')
        .gsub(/--/, '__')
    end

    define_combinator :doc do
      many(tag | text) < eof
    end

    define_combinator :text do
      join(many(any_char.that_fail(tag))).fmap do |str|
        { text: str.force_encoding('utf-8').encode }
      end
    end

    define_combinator :tag do
      between(tag_delimiter, tag_delimiter, tag_text).fmap do |tag|
        { tag: TagsParser.normalize(tag) }
      end
    end

    define_combinator :tag_delimiter do
      lit('--')
    end

    define_combinator :tag_text_first_char do
      any_char.that_fail(lit('-') | tag_delimiter | eol)
    end

    define_combinator :tag_text_char do
      any_char.that_fail(tag_delimiter | eol)
    end

    define_combinator :tag_text do
      join(single(tag_text_first_char) + many(tag_text_char)).fmap do |str|
        str.force_encoding('utf-8').encode.gsub(/[[:space:]]/, ' ')
      end
    end

    define_combinator :eol do
      lit("\r\n") | lit("\n")
    end
  end

  DOSSIER_ID_TAG = {
    id: 'dossier_number',
      label: 'numéro du dossier',
      libelle: 'numéro du dossier',
      description: '',
      lambda: -> (d) { d.id },
      available_for_states: Dossier::SOUMIS,
  }

  DOSSIER_TAGS = [
    {
      id: 'dossier_motivation',
      libelle: 'motivation',
      description: 'Motivation facultative associée à la décision finale d’acceptation, refus ou classement sans suite',
      lambda: -> (d) { simple_format(d.motivation) },
      escapable: false, # sanitized by simple_format
      available_for_states: Dossier::TERMINE,
    },
    {
      id: 'dossier_depose_at',
      libelle: 'date de dépôt',
      description: 'Date de dépôt du dossier par l’usager',
      lambda: -> (d) { format_date(d.depose_at) },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'dossier_en_instruction_at',
      libelle: 'date de passage en instruction',
      description: '',
      lambda: -> (d) { format_date(d.en_instruction_at) },
      available_for_states: Dossier::INSTRUCTION_COMMENCEE,
    },
    {
      id: 'dossier_processed_at',
      libelle: 'date de décision',
      description: 'Date de la décision d’acceptation, refus, ou classement sans suite',
      lambda: -> (d) { format_date(d.processed_at) },
      available_for_states: Dossier::TERMINE,
    },
    {
      id: 'dossier_last_champ_updated_at',
      libelle: 'date de mise à jour',
      description: 'Date de dernière mise à jour d’un champ du dossier',
      lambda: -> (d) { format_date(d.last_champ_updated_at) },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'dossier_procedure_libelle',
      libelle: 'libellé démarche',
      description: '',
      lambda: -> (d) { d.procedure.libelle },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'dossier_service_name',
      libelle: 'nom du service',
      description: 'Le nom du service de la démarche',
      lambda: -> (d) { d.procedure.organisation_name || '' },
      available_for_states: Dossier::SOUMIS,
    },
  ].push(DOSSIER_ID_TAG)

  DOSSIER_TAGS_FOR_MAIL = [
    {
      id: 'dossier_url',
      libelle: 'lien dossier',
      description: '',
      lambda: -> (d) { external_link(dossier_url(d, host:)) },
      available_for_states: Dossier::SOUMIS,
      escapable: false,
    },
    {
      id: 'dossier_attestation_url',
      libelle: 'lien attestation',
      description: '',
      lambda: -> (d) { external_link(attestation_dossier_url(d, host:)) },
      available_for_states: [Dossier.states.fetch(:accepte), Dossier.states.fetch(:refuse)],
      escapable: false,
    },
    {
      id: 'dossier_motivation_url',
      libelle: 'lien document justificatif',
      description: '',
      lambda: -> (d) {
        if d.justificatif_motivation.attached?
          external_link(url_for_justificatif_motivation(d), "Télécharger le document justificatif")
        else
          return "[l’instructeur n’a pas joint de document supplémentaire]"
        end
      },
      available_for_states: Dossier::TERMINE,
      escapable: false,
    },
  ]

  DOSSIER_SVA_SVR_DECISION_DATE_TAG = {
    id: 'dossier_sva_svr_decision_on',
    libelle: 'date prévisionnelle SVA/SVR',
    description: 'Date prévisionnelle de décision automatique par le SVA/SVR',
    lambda: -> (d) { format_date(d.sva_svr_decision_on) },
    available_for_states: Dossier.states.fetch(:en_instruction),
  }

  INDIVIDUAL_TAGS = [
    {
      id: 'individual_gender',
      libelle: 'civilité',
      description: 'M., Mme',
      lambda: -> (d) { d.individual&.gender },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'individual_last_name',
      libelle: 'nom',
      description: "nom de l’usager",
      lambda: -> (d) { d.individual&.nom },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'individual_first_name',
      libelle: 'prénom',
      description: "prénom de l’usager",
      lambda: -> (d) { d.individual&.prenom },
      available_for_states: Dossier::SOUMIS,
    },
  ]

  ENTREPRISE_TAGS = [
    {
      id: 'entreprise_siren',
      libelle: 'SIREN',
      description: '',
      lambda: -> (d) { d.etablissement&.entreprise&.siren },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'entreprise_numero_tva_intracommunautaire',
      libelle: 'numéro de TVA intracommunautaire',
      description: '',
      lambda: -> (d) { d.etablissement&.entreprise&.numero_tva_intracommunautaire },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'entreprise_siret_siege_social',
      libelle: 'SIRET du siège social',
      description: '',
      lambda: -> (d) { d.etablissement&.entreprise&.siret_siege_social },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'entreprise_raison_sociale',
      libelle: 'raison sociale',
      description: '',
      lambda: -> (d) { d.etablissement&.entreprise&.raison_sociale },
      available_for_states: Dossier::SOUMIS,
    },
    {
      id: 'entreprise_adresse',
      libelle: 'adresse',
      description: '',
      lambda: -> (d) { d.etablissement&.entreprise&.inline_adresse },
      available_for_states: Dossier::SOUMIS,
    },
  ]

  ROUTAGE_TAGS = [
    {
      id: 'dossier_groupe_instructeur',
      libelle: 'groupe instructeur',
      description: 'Le groupe instructeur en charge du dossier',
      lambda: -> (d) { d.groupe_instructeur&.label },
      available_for_states: Dossier::SOUMIS,
    },
  ]

  CONTACT_INFORMATION_NAME_TAG = {
    id: 'dossier_contact_information_name',
    libelle: 'nom du service instructeur',
    description: 'Le nom du service qui traite le dossier (celui des informations de contact du groupe instructeur s’il existe, sinon celui de la démarche)',
    lambda: -> (d) { d.service_or_contact_information&.nom || '' },
    available_for_states: Dossier::SOUMIS,
  }

  SHARED_TAG_IDS = (DOSSIER_TAGS + DOSSIER_TAGS_FOR_MAIL + INDIVIDUAL_TAGS + ENTREPRISE_TAGS + ROUTAGE_TAGS).map { _1[:id] }

  def identity_tags
    if procedure.for_individual?
      INDIVIDUAL_TAGS
    else
      ENTREPRISE_TAGS
    end
  end

  def routage_tags
    if procedure.routing_enabled?
      ROUTAGE_TAGS
    else
      []
    end
  end

  def tags
    tags_for_dossier_state(identity_tags + dossier_tags + champ_public_tags + champ_private_tags + routage_tags)
  end

  def tags_categorized
    identity_key = procedure.for_individual? ? :individual : :etablissement

    {
      identity_key => tags_for_dossier_state(identity_tags),
      dossier: tags_for_dossier_state(dossier_tags + routage_tags),
      champ_public: tags_for_dossier_state(champ_public_tags),
      champ_private: tags_for_dossier_state(champ_private_tags),
    }.reject { |_, ary| ary.empty? }
  end

  def used_type_de_champ_tags(text_or_tiptap)
    used_tags =
      if text_or_tiptap.respond_to?(:deconstruct_keys) # hash pattern matching
        TiptapService.used_tags_and_libelle_for(text_or_tiptap.deep_symbolize_keys)
      else
        used_tags_and_libelle_for(text_or_tiptap.to_s)
      end

    used_tags.filter_map do |(tag, libelle)|
      if tag.nil?
        [libelle]
      elsif !tag.in?(SHARED_TAG_IDS) && tag.start_with?('tdc')
        [libelle, tag.gsub(/^tdc/, '').to_i]
      end
    end
  end

  def used_tags_for(text)
    used_tags_and_libelle_for(text).map { _1.first.nil? ? _1.second : _1.first }
  end

  def tags_substitutions(tags_and_libelles, dossier, escape: true, memoize: false)
    # NOTE:
    # - tags_and_libelles est un simple Set de couples (tag_id, libelle) (pas la même structure que dans replace_tags)
    # - dans `replace_tags`, on fait référence à des tags avec ou sans id, mais pas ici,
    #   (inutile car tiptap ne référence que des ids)

    @escape_unsafe_tags = escape

    flat_tags = if memoize && @flat_tags.present?
      @flat_tags
    else
      available_tags(dossier)
        .flatten
        .then { tags_for_dossier_state(_1) }
        .index_by { _1[:id] }
    end

    @flat_tags = flat_tags if memoize

    tags_and_libelles.each_with_object({}) do |(tag_id, libelle), substitutions|
      substitutions[tag_id] = if flat_tags[tag_id].present?
        replace_tag(flat_tags[tag_id], dossier)
      else # champ not in dossier, for example during preview on draft revision
        libelle
      end
    end
  end

  private

  # i18n-tasks-use t('date.formats.short_date')
  # i18n-tasks-use t('date.formats.dashed')
  # i18n-tasks-use t('time.formats.short_date')
  # i18n-tasks-use t('time.formats.human')
  # i18n-tasks-use t('time.formats.long')
  # i18n-tasks-use t('time.formats.short_datetime')
  # i18n-tasks-use t('time.formats.dashed')
  def format_date(date)
    if date.present?
      format = defined?(self.class::FORMAT_DATE) ? self.class::FORMAT_DATE : :short_date
      I18n.l(date, format:)
    else
      ''
    end
  end

  def external_link(url, title = nil)
    link_to(title || url, url, target: '_blank', rel: 'noopener')
  end

  def url_for_justificatif_motivation(dossier)
    if dossier.justificatif_motivation.attached?
      Rails.application.routes.url_helpers.rails_blob_url(dossier.justificatif_motivation, host:)
    end
  end

  def dossier_tags
    # Overridden by MailTemplateConcern
    DOSSIER_TAGS + contextual_dossier_tags
  end

  def contextual_dossier_tags
    tags = []

    return tags unless respond_to?(:procedure)

    tags << DOSSIER_SVA_SVR_DECISION_DATE_TAG if procedure.sva_svr_enabled?

    if procedure.routing_enabled?
      has_contact_info = procedure.groupe_instructeurs
        .includes(:contact_information)
        .any? { |gi| gi.contact_information.present? }
      tags << CONTACT_INFORMATION_NAME_TAG if has_contact_info
    end

    tags
  end

  def tags_for_dossier_state(tags)
    # Implementation note: emails and attestation generations are generally
    # triggerred by changes to the dossier’s state. The email or attestation
    # is generated right after the dossier has reached its new state.
    #
    # DOSSIER_STATE should be equal to this new state.
    #
    # For instance, for an email that gets generated for the brouillon->en_construction
    # transition, DOSSIER_STATE should equal 'en_construction'.

    if !defined?(self.class::DOSSIER_STATE)
      raise NameError.new("The class #{self.class.name} includes TagsSubstitutionConcern, it should define the DOSSIER_STATE constant but it does not", :DOSSIER_STATE)
    end

    tags.filter { |tag| tag[:available_for_states].include?(self.class::DOSSIER_STATE) }
  end

  def champ_public_tags(dossier: nil)
    types_de_champ = (dossier || procedure.active_revision).types_de_champ_public.filter { !_1.condition? }
    types_de_champ_tags(types_de_champ, Dossier::SOUMIS)
  end

  def champ_private_tags(dossier: nil)
    types_de_champ = (dossier || procedure.active_revision).types_de_champ_private.filter { !_1.condition? }
    types_de_champ_tags(types_de_champ, Dossier::INSTRUCTION_COMMENCEE)
  end

  def types_de_champ_tags(types_de_champ, available_for_states)
    tags = types_de_champ.flat_map(&:tags_for_template)
    tags.each do |tag|
      tag[:available_for_states] = available_for_states
    end
    tags
  end

  def replace_tags(text, dossier, escape: true)
    if text.nil?
      return ''
    end

    @escape_unsafe_tags = escape

    tokens = parse_tags(text)

    tags_and_datas = available_tags(dossier).filter_map do |tags|
      dossier && [tags_for_dossier_state(tags).index_by { _1[:id] }, dossier]
    end

    tags_and_datas.reduce(tokens) do |tokens, (tags, data)|
      # Replace tags with their value
      tokens.map do |token|
        case token
        in { tag: _, id: id } if tags.key?(id)
          { text: replace_tag(tags.fetch(id), data) }
        in { tag: tag } if tags.key?(tag)
          { text: replace_tag(tags.fetch(tag), data) }
        else
          token
        end
      end
    end.map do |token|
      # Get tokens text representation
      case token
      in { tag: tag }
        "--#{tag}--"
      in { text: text }
        text
      end
    end.join('')
  end

  def replace_tag(tag, dossier)
    value = instance_exec(dossier, &tag[:lambda])

    if escape_unsafe_tags? && tag.fetch(:escapable, true)
      escape_once(value)
    else
      value
    end
  end

  def escape_unsafe_tags?
    @escape_unsafe_tags
  end

  def procedure_types_de_champ_tags
    tags_for_dossier_state(types_de_champ_tags(procedure.types_de_champ_public_for_tags, Dossier::SOUMIS) +
      types_de_champ_tags(procedure.types_de_champ_private_for_tags, Dossier::INSTRUCTION_COMMENCEE) +
      identity_tags + dossier_tags + ROUTAGE_TAGS)
  end

  def parse_tags(text)
    tags = procedure_types_de_champ_tags.index_by { _1[:libelle] }

    # MD5 should be enough and it avoids long key
    tokens = Rails.cache.fetch(["parse_tags_v2", Digest::MD5.hexdigest(text)], expires_in: 1.day) { TagsParser.parse(text) }
    tokens.map do |token|
      case token
      in { tag: tag } if tags.key?(tag)
        { tag: tag, id: tags.fetch(tag).fetch(:id) }
      else
        token
      end
    end
  end

  def used_tags_and_libelle_for(text)
    parse_tags(text).filter_map do |token|
      case token
      in { tag: tag, id: id }
        [id, tag]
      in { tag: tag }
        [nil, tag]
      else
        nil
      end
    end
  end

  def available_tags(dossier)
    [
      champ_public_tags(dossier:),
      champ_private_tags(dossier:),
      dossier_tags,
      ROUTAGE_TAGS,
      INDIVIDUAL_TAGS,
      ENTREPRISE_TAGS,
    ]
  end

  def host = Current.host || ENV["APP_HOST"]
end
