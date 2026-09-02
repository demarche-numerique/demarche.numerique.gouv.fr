# frozen_string_literal: true

# Payload of the dossier PDF (lib/typst/root/dossier.typ, rendered by
# DossierPdfService through TypstService): already-localized French strings
# and a small discriminated union of champ blocks - layout lives in the
# template and theme. Champ values go through the columns API
# (TypeDeChamp#canonical_column for the value, #columns for the detail rows),
# so the PDF shows what the dossier tables and exports show.
class Typst::DossierPayload < Typst::Payload
  BLANK = 'Non communiqué'
  PENDING_ANSWER = 'En attente de réponse'

  # Dossier columns of the requester's identity (the same ones as
  # ColumnsConcern#individual_columns and #moral_columns), in printing order.
  INDIVIDUAL_COLUMNS = [
    ['individual', 'gender', :text],
    ['individual', 'nom', :text],
    ['individual', 'prenom', :text],
    ['self', 'for_tiers', :boolean],
    ['self', 'mandataire_last_name', :text],
    ['self', 'mandataire_first_name', :text],
  ].freeze

  ETABLISSEMENT_COLUMN_TYPES = Etablissement::DISPLAYABLE_COLUMNS
    .merge(Etablissement::EXPORTABLE_ETABLISSEMENT_COLUMNS, Etablissement::EXPORTABLE_ASSOCIATION_COLUMNS)
    .transform_values { it[:type] }
    .freeze

  ETABLISSEMENT_COLUMNS = %w[
    siret
    entreprise_siret_siege_social
    entreprise_raison_sociale
    entreprise_forme_juridique
    entreprise_capital_social
    libelle_naf
    code_naf
    entreprise_date_creation
    entreprise_etat_administratif
    entreprise_code_effectif_entreprise
    entreprise_numero_tva_intracommunautaire
    adresse
    association_rna
    association_titre
    association_objet
    association_date_creation
    association_date_publication
    association_date_declaration
  ].freeze

  attr_reader :dossier, :procedure, :acls, :assets

  # acls: PiecesJustificativesService#acl_for_dossier_export
  # assets: TypstService::Assets, for the images the document embeds
  def initialize(dossier, acls:, assets:)
    super()
    @dossier = dossier
    @procedure = dossier.procedure
    @acls = acls
    @assets = assets
  end

  def to_h
    {
      # Pinned: every string of this document is authored in French, as the
      # labels of the dossier tables it mirrors.
      lang: 'fr',
      title: "Dossier n° #{dossier.id}",
      procedure: procedure.libelle,
      date: "Édité le #{I18n.l(Date.current, format: '%e %B %Y').squish}",
      **TypstService.letterhead,
      draft_warning:,
      sections: [dossier_section, identity_section],
      form: champs_section('Formulaire', dossier.root_champs_public),
      annotations: annotations_section,
      avis: avis_section,
      messages: messages_section,
    }
  end

  private

  def helpers = ApplicationController.helpers

  def procedure_id = procedure.id

  def draft_warning
    return if !dossier.revision.draft?

    {
      title: 'Démarche en test',
      text: 'Ce dossier est déposé sur une démarche en test par l’administration. ' \
            'Il peut être supprimé à tout moment et sans préavis, même après avoir été accepté.',
    }
  end

  # -- Dossier and identity sections (key/value rows)

  def dossier_section
    rows = [
      ['Organisme', procedure.organisation_name.presence],
      ['État', dossier_state],
      dossier_column_row('motivation', :text),
      dossier_column_row('depose_at', :datetime),
      pending_correction_row,
      dossier_column_row('en_instruction_at', :datetime),
      *sva_svr_rows,
      dossier_column_row('processed_at', :datetime),
    ]

    { title: 'Dossier', rows: rows.filter { it&.last.present? } }
  end

  def dossier_state
    state = helpers.dossier_display_state(dossier)
    dossier.pending_correction? ? "#{state} (en attente de correction)" : state
  end

  def pending_correction_row
    return if !dossier.pending_correction?

    ['Correction demandée le', I18n.l(dossier.pending_corrections.first.created_at, format: :short_with_time)]
  end

  def sva_svr_rows
    return [] if !procedure.sva_svr_enabled?

    decision = procedure.sva_svr_configuration.human_decision

    if dossier.sva_svr_decision_triggered_at.present?
      [["Décision #{decision} prise le", I18n.l(dossier.sva_svr_decision_triggered_at, format: :short_with_time)]]
    elsif dossier.sva_svr_decision_on.present?
      value = if dossier.pending_correction?
        "#{dossier.sva_svr_decision_in_days} jours après la correction"
      else
        I18n.l(dossier.sva_svr_decision_on)
      end
      [["Date prévisionnelle #{decision}", value]]
    else
      []
    end
  end

  # Dossier columns are built on the spot, like ColumnsConcern does (the label
  # is the procedure_presentation one): the procedure's column list aggregates
  # every revision, while this document is the dossier's own revision.
  def dossier_column(table, name, type) = Columns::DossierColumn.new(procedure_id:, table:, column: name, type:)

  def dossier_column_row(name, type) = row_for(dossier_column('self', name, type), dossier)

  def identity_section
    rows = []

    if dossier.france_connected_with_one_identity?
      rows << ['Informations FranceConnect', helpers.france_connect_informations(dossier.user.france_connect_informations.first)]
    end

    rows << [User.human_attribute_name(:email), dossier.user_email_for(:display)]

    if dossier.individual.present?
      rows.concat(INDIVIDUAL_COLUMNS.filter_map do |(table, name, type)|
        # (the individual columns are labelled for the filters: "Nom [Identité du demandeur]")
        row_for(dossier_column(table, name, type), dossier, label: table == 'individual' ? Individual.human_attribute_name(name) : nil)
      end)
      if dossier.individual.birthdate.present?
        rows << [Individual.human_attribute_name(:birthdate), I18n.l(dossier.individual.birthdate)]
      end
    elsif dossier.etablissement.present?
      rows.concat(etablissement_rows)
    end

    { title: 'Identité du demandeur', rows: }
  end

  def etablissement_rows
    rows = ETABLISSEMENT_COLUMNS.filter_map { |name| row_for(dossier_column('etablissement', name, ETABLISSEMENT_COLUMN_TYPES.fetch(name, :text)), dossier) }
    rows.concat(effectif_rows(dossier.etablissement)) if acls[:include_infos_administration]
    rows
  end

  # (not columns: the effectifs are administration-only information)
  def effectif_rows(etablissement)
    rows = []
    if etablissement.entreprise_effectif_mensuel.present?
      rows << ["Effectif mensuel #{helpers.try_format_mois_effectif(etablissement)} de l’établissement (URSSAF ou MSA)", helpers.number_with_delimiter(etablissement.entreprise_effectif_mensuel.to_s)]
    end
    if etablissement.entreprise_effectif_annuel_annee.present?
      rows << ["Effectif moyen annuel #{etablissement.entreprise_effectif_annuel_annee} de l’unité légale (URSSAF ou MSA)", helpers.number_with_delimiter(etablissement.entreprise_effectif_annuel.to_s)]
    end
    rows
  end

  # [label, value] of a dossier column, nil when the record holds nothing for
  # it (a false boolean included: "pour le compte d'un tiers : non" is noise).
  def row_for(column, record, label: nil)
    return if column.nil?

    raw = column.value(record)
    return if raw.blank?

    value = format_value(column, raw)
    [label || column.label, value] if value.present?
  end

  # -- Champs

  def champs_section(title, champs)
    # Level of the last heading emitted; the section's own h2 precedes the champs.
    @heading_level = 2
    { title:, champs: champ_blocks(champs) }
  end

  def annotations_section
    return if !acls[:include_infos_administration] || !dossier.has_annotations?

    champs_section('Annotations privées', dossier.root_champs_private)
  end

  def champ_blocks(champs) = champs.filter_map { champ_block(it) }

  def champ_block(champ)
    return if !displayed?(champ)

    case champ.type_de_champ.type_champ
    when TypeDeChamp.type_champs.fetch(:header_section)
      heading_block(champ.type_de_champ)
    when TypeDeChamp.type_champs.fetch(:explication)
      { type: 'explication', label: champ.libelle, text: Typst::RichText.from_markdown(champ.type_de_champ.description) }
    when TypeDeChamp.type_champs.fetch(:repetition)
      repetition_block(champ)
    when TypeDeChamp.type_champs.fetch(:carte)
      champ.blank? ? blank_block(champ) : carte_block(champ)
    else
      champ.blank? ? blank_block(champ) : field_block(champ)
    end
  end

  # Same rule as the web view (Dossiers::ChampsRowsShowComponent): a champ
  # hidden by a condition stays visible to the instructeur when the usager
  # had filled it in the revision they submitted.
  def displayed?(champ)
    return true if champ.visible?

    acls[:include_hidden_submitted_champs] && champ.public? && champ.submitted_filled?
  end

  def heading_block(type_de_champ)
    # (typst rejects an empty heading under PDF/UA-1)
    return if type_de_champ.libelle.blank?

    text = if dossier.auto_numbering_section_headers_for?(type_de_champ)
      "#{dossier.index_for_section_header(type_de_champ)}. #{type_de_champ.libelle}"
    else
      type_de_champ.libelle
    end

    { type: 'heading', level: heading_level(type_de_champ), text: }
  end

  # PDF/UA-1 rejects skipped heading levels, and a revision can legitimately
  # hold a gap (cf. DossierVidePayload): clamp each heading to at most one
  # level below the previous one, capped at h6.
  def heading_level(type_de_champ)
    @heading_level = [type_de_champ.level_for_revision(dossier.revision) + 2, @heading_level + 1, 6].min
  end

  def blank_block(champ) = { type: 'field', label: champ.libelle, value: BLANK, blank: true, details: [] }

  # Value from the canonical column, detail rows from the other displayable
  # columns of the champ (address parts, etablissement data, RIB, referentiel
  # columns...). FranceConnect champs have no meaningful canonical value (the
  # confirmation flag): their columns carry the fetched data, and the
  # documents uploaded instead are listed when nothing was fetched.
  def field_block(champ)
    type_de_champ = champ.type_de_champ
    canonical = type_de_champ.is_a?(TypesDeChamp::FranceConnectTypeDeChamp) ? nil : type_de_champ.canonical_column(procedure_id:)
    raw = canonical&.value(champ)

    return files_block(champ, raw) if canonical&.type == :attachments

    details = detail_rows(type_de_champ, champ, canonical)
    value = format_value(canonical, raw)

    if value.blank? && details.empty?
      return files_block(champ, champ.piece_justificative_file.to_a) if champ.respond_to?(:piece_justificative_file)

      return blank_block(champ)
    end

    { type: 'field', label: champ.libelle, value:, blank: false, details: }
  end

  def files_block(champ, attachments)
    return blank_block(champ) if attachments.blank?

    { type: 'files', label: champ.libelle, files: attachments.map { it.filename.to_s } }
  end

  def detail_rows(type_de_champ, champ, canonical)
    type_de_champ.columns(procedure_id:)
      .filter { it.displayable && (canonical.nil? || it.column_id != canonical.column_id) }
      .filter_map do |column|
        value = format_value(column, column.value(champ))
        [detail_label(type_de_champ, column), value] if value.present?
      end
  end

  # "Adresse – Code postal" -> "Code postal" (cf. TypeDeChamp#info_columns)
  def detail_label(type_de_champ, column)
    column.label.sub(/\A#{Regexp.escape(type_de_champ.libelle)}[^\p{L}]+/, '')
  end

  def carte_block(champ)
    {
      type: 'carte',
      label: champ.libelle,
      map: static_map(champ),
      areas: champ.geo_areas.map { { label: it.label, description: it.description.presence } },
    }
  end

  # The map is rendered asynchronously (RenderCarteChampJob), so it can be
  # missing on an older dossier or right after a submission; the list of
  # geometries that follows stays the only representation then.
  def static_map(champ)
    return if !champ.static_map.attached?

    assets.image(champ.static_map, alt: "Carte des zones dessinées pour « #{champ.libelle} »")
  rescue ActiveStorage::Error => e
    Sentry.capture_exception(e, extra: { dossier: dossier.id, champ: champ.id })
    nil
  end

  def repetition_block(champ)
    rows = champ.rows.each_with_index.map do |row, index|
      { title: "#{champ.libelle} #{index + 1}", champs: champ_blocks(row) }
    end

    return blank_block(champ) if rows.empty?

    { type: 'repetition', label: champ.libelle, rows: }
  end

  # Plain-text rendering of a column value; numbers get their thousands
  # separators like on the web.
  def format_value(column, raw)
    return if column.nil? || raw.nil?

    case column.type
    when :integer, :decimal
      helpers.number_with_delimiter(raw)
    when :text
      raw.is_a?(Date) || raw.is_a?(Time) ? I18n.l(raw) : ColumnValueFormatter.format(column:, raw_value: raw, html: false).to_s.presence
    else
      ColumnValueFormatter.format(column:, raw_value: raw, html: false).to_s.presence
    end
  end

  # -- Avis and messagerie

  def avis_section
    return if !acls[:include_infos_administration] && !acls[:include_avis_for_expert]

    avis = acls[:only_for_expert] ? dossier.avis_for_expert(acls[:only_for_expert]) : dossier.avis
    return if avis.blank?

    { title: 'Avis', items: avis.map { avis_item(it) } }
  end

  def avis_item(avis)
    binary = avis.question_label.present?

    {
      title: "Avis demandé à #{avis.email_to_display}#{avis.confidentiel? ? ' (confidentiel)' : ''}",
      question: "« #{avis.introduction} »",
      answer: avis.answer.presence || PENDING_ANSWER,
      binary_question: binary ? "« #{avis.question_label} »" : nil,
      binary_answer: binary ? binary_answer(avis) : nil,
    }
  end

  def binary_answer(avis)
    return PENDING_ANSWER if avis.question_answer.nil?

    I18n.t("helpers.label.question_answer.#{avis.question_answer}")
  end

  def messages_section
    return if !acls[:include_messagerie] || dossier.commentaires.blank?

    # (preloaded association, sorted in memory)
    { title: 'Messagerie', items: dossier.commentaires.sort_by(&:created_at).map { message_item(it) } }
  end

  def message_item(commentaire)
    sender = if commentaire.sent_by_system?
      'Email automatique'
    elsif commentaire.sent_by?(dossier.user)
      dossier.user_email_for(:display)
    else
      commentaire.redacted_email
    end

    { sender:, date: I18n.l(commentaire.created_at, format: :short_with_time), body: plain_text(commentaire.body) }
  end

  # Message bodies are HTML: keep the line structure, drop the tags.
  def plain_text(html)
    CGI.unescapeHTML(ActionView::Base.full_sanitizer.sanitize(html.to_s.gsub(%r{<br\s*/?>|</p>}i, "\n"))).strip
  end
end
