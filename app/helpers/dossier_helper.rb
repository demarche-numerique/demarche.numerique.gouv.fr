# frozen_string_literal: true

module DossierHelper
  include EtablissementHelper

  def button_or_label_class(dossier)
    if dossier.accepte?
      'accepted'
    elsif dossier.sans_suite?
      'without-continuation'
    elsif dossier.refuse?
      'refused'
    end
  end

  def highlight_if_unseen_class(seen_at, updated_at)
    if updated_at.present? && seen_at&.<(updated_at)
      "highlighted"
    end
  end

  def url_for_dossier(dossier)
    if dossier.brouillon?
      brouillon_dossier_path(dossier)
    else
      dossier_path(dossier)
    end
  end

  def url_for_new_dossier(revision)
    new_dossier_url(procedure_id: revision.procedure.id, brouillon: revision.draft? ? true : nil)
  end

  def commencer_dossier_vide_for_revision_path(revision)
    revision.draft? ? commencer_dossier_vide_test_path(path: revision.procedure.path) : commencer_dossier_vide_path(path: revision.procedure.path)
  end

  def dossier_submission_is_closed?(dossier)
    dossier.brouillon? && dossier.procedure.close?
  end

  def dossier_display_state(dossier_or_state, lower: false, profile: nil)
    state = dossier_or_state.is_a?(Dossier) ? dossier_or_state.state : dossier_or_state

    key = profile == :user ? Users::DossierStateMapping::USER_FACING_LABEL_KEYS.fetch(state, state) : state
    display_state = Dossier.human_attribute_name("state.#{key}")

    lower ? display_state.downcase : display_state
  end

  def dossier_legacy_state(dossier)
    case dossier.state
    when Dossier.states.fetch(:en_construction)
      'initiated'
    when Dossier.states.fetch(:en_instruction)
      'received'
    when Dossier.states.fetch(:accepte)
      'closed'
    when Dossier.states.fetch(:refuse)
      'refused'
    when Dossier.states.fetch(:sans_suite)
      'without_continuation'
    else
      dossier.state
    end
  end

  def class_badge_state(state)
    case state
    when Dossier.states.fetch(:en_construction)
      'fr-badge--purple-glycine'
    when Dossier.states.fetch(:en_instruction)
      'fr-badge--new'
    when Dossier.states.fetch(:accepte)
      'fr-badge--success'
    when Dossier.states.fetch(:refuse), Dossier.states.fetch(:sans_suite)
      'fr-badge--warning'
    when Dossier.states.fetch(:brouillon)
      ''
    else
      ''
    end
  end

  def status_badge_user(dossier, alignment_class = '')
    if dossier.hide_info_with_accuse_lecture?
      tag.span 'traité', class: "fr-badge fr-badge--sm fr-badge--no-icon #{alignment_class}"
    else
      status_badge(dossier.state, alignment_class, profile: :user)
    end
  end

  def status_badge(state, alignment_class = '', profile: nil)
    status_text = dossier_display_state(state, lower: true, profile:)
    tag.span status_text, class: class_names(
      'fr-badge fr-badge--sm' => true,
      'fr-badge--no-icon' => Dossier.states.fetch(:accepte).exclude?(state),
      class_badge_state(state) => true,
      alignment_class => true
    )
  end

  def deletion_reason_badge(reason)
    if reason.present?
      status_text = t(reason, scope: 'activerecord.attributes.deleted_dossier.reason')
      status_class = reason.tr('_', '-')
    else
      status_text = t('activerecord.attributes.deleted_dossier.reason.unknown')
      status_class = 'unknown'
    end

    tag.span(status_text, class: "fr-badge #{status_class} ")
  end

  def expiration_badge(dossier, html_class: nil)
    return if !dossier.expirable? || !dossier.close_to_expiration?

    tag.span(
      t('views.users.dossiers.dossiers_list.expiration_badge', count: dossier.nb_days_before_expiration),
      class: class_names("fr-badge fr-badge--sm fr-badge--warning", html_class => true)
    )
  end

  def partage_badge(html_class: nil)
    tag.span(
      Dossier.human_attribute_name("partage.for_user"),
      class: class_names("fr-badge fr-badge--sm fr-badge--blue-cumulus", html_class => true)
    )
  end

  def new_message_badge(html_class: nil)
    tag.span(
      Dossier.human_attribute_name("new_message.for_user"),
      class: class_names("fr-badge fr-badge--sm fr-badge--new", html_class => true)
    )
  end

  def show_new_message_notification?(dossier)
    return false unless current_user.dossiers_alerts_enabled?

    # Le badge « nouveau message » passe derrière « à corriger » et « en attente
    # de réponse » : on n'affiche qu'un seul badge de type messagerie à la fois.
    return false if dossier.pending_correction? || dossier.pending_response?

    # `.any?` lit l'association préchargée en mémoire (cf. USER_LIST_PRELOADS) :
    # aucune requête supplémentaire dans la liste des dossiers.
    dossier.unread_messages_for_user.any?
  end

  def pending_correction_badge(profile, html_class: nil)
    tag.span(Dossier.human_attribute_name("pending_correction.#{profile}"), class:
      class_names(
        "fr-badge fr-badge--sm",
        "fr-badge--warning super" => profile == :for_user,
        html_class => true
      ))
  end

  def correction_resolved_badge(type, html_class: nil)
    tag.span(Dossier.human_attribute_name("pending_correction.#{type}"), class: ['fr-badge fr-badge--sm', html_class])
  end

  def pending_response_badge(profile, html_class: nil)
    tag.span(Dossier.human_attribute_name("attente_reponse.#{profile}"), class:
      class_names(
        "fr-badge fr-badge--sm",
        "fr-badge--warning super" => profile == :for_user,
        html_class => true
      ))
  end

  def response_resolved_badge(status, html_class: nil)
    tag.span(Dossier.human_attribute_name("attente_reponse.#{status}"), class: ['fr-badge fr-badge--sm', html_class])
  end

  def tags_label(labels)
    if labels.size > 1
      tag.ul(class: 'fr-tags-group') do
        safe_join(labels.map { |l| tag.li(tag_label(l.name, l.color)) })
      end
    elsif labels.one?
      label = labels.first
      tag_label(label.name, label.color)
    end
  end

  def tag_label(name, color)
    tag.span(name, class: "fr-tag fr-tag--sm fr-tag--#{Label.class_name(color)} no-wrap")
  end

  def tag_summary_notification(notification_type_count)
    type, count = notification_type_count

    tag.span(class: [badge_notification_class(type), 'fr-badge--no-icon']) do
      safe_join([
        tag.span(count, class: "fr-background-alt--grey fr-my-1v fr-mr-1v fr-px-1v fr-text-default--grey"),
        tag.span(nil, class: [badge_notification_class(type), 'fr-my-0', 'fr-mx-0', 'fr-px-0'], aria: { hidden: true }),
        tag.span(badge_notification_text_a11y(type, summary: true), class: "fr-sr-only"),
        badge_notification_text(type, generic: true),
      ])
    end
  end

  def tags_summary_notification(notifications_counts_by_type)
    tag.ul(class: 'fr-badge-group fr-mt-2w') do
      safe_join(notifications_counts_by_type.map { |notif| tag.li(tag_summary_notification(notif)) })
    end
  end

  def tag_notification(notification, generic: false)
    safe_join([
      tag.span(badge_notification_text(notification, generic:), class: badge_notification_class(notification)),
      tag.span(badge_notification_text_a11y(notification, summary: false), class: "fr-sr-only"),
    ])
  end

  def tags_notification(notifications, generic: false)
    tag.ul(class: 'fr-badge-group') do
      safe_join(notifications.map { |notif| tag.li(tag_notification(notif, generic:)) })
    end
  end

  def badge_notification_class(notification)
    type = extract_notification_type(notification)

    case type
    when DossierNotification.notification_types.fetch(:dossier_depose),
      DossierNotification.notification_types.fetch(:dossier_expirant),
      DossierNotification.notification_types.fetch(:dossier_suppression)
      "fr-badge fr-badge--sm fr-badge--warning"
    when DossierNotification.notification_types.fetch(:dossier_modifie),
      DossierNotification.notification_types.fetch(:message),
      DossierNotification.notification_types.fetch(:annotation_instructeur),
      DossierNotification.notification_types.fetch(:avis_externe)
      "fr-badge fr-badge--sm fr-badge--new"
    when DossierNotification.notification_types.fetch(:attente_correction),
      DossierNotification.notification_types.fetch(:attente_avis),
      DossierNotification.notification_types.fetch(:attente_reponse)
      "fr-badge fr-badge--sm"
    end
  end

  def badge_notification_text(notification, generic)
    type = extract_notification_type(notification)

    case type
    when DossierNotification.notification_types.fetch(:dossier_depose),
      DossierNotification.notification_types.fetch(:dossier_expirant),
      DossierNotification.notification_types.fetch(:dossier_suppression)
      if generic[:generic]
        t("activerecord.attributes.notification.#{type}.generic")
      else
        days = days_for_specific_badge_notification(notification, type)
        t("activerecord.attributes.notification.#{type}.specific", days: days)
      end
    else
      t("activerecord.attributes.notification.#{type}")
    end
  end

  def badge_notification_text_a11y(notification, summary:)
    type = extract_notification_type(notification)

    case type
    when DossierNotification.notification_types.fetch(:dossier_modifie),
      DossierNotification.notification_types.fetch(:message),
      DossierNotification.notification_types.fetch(:annotation_instructeur),
      DossierNotification.notification_types.fetch(:avis_externe)
      if summary
        t("activerecord.attributes.notification.a11y.news.for_summary")
      else
        t("activerecord.attributes.notification.a11y.news.for_not_summary")
      end
    else
      t("activerecord.attributes.notification.a11y.others") if summary
    end
  end

  def demandeur_dossier(dossier)
    if dossier.procedure.for_individual? && dossier.for_tiers?
      return t('shared.dossiers.beneficiaire', mandataire: dossier.mandataire_full_name, beneficiaire: "#{dossier&.individual&.prenom} #{dossier&.individual&.nom}")
    end

    if dossier.procedure.for_individual?
      return "#{dossier&.individual&.prenom} #{dossier&.individual&.nom}"
    end

    return "" if dossier.etablissement.blank?

    if dossier.etablissement.diffusable_commercialement == false
      "SIRET #{pretty_siret(dossier.etablissement.siret)}"
    else
      raison_sociale_or_name(dossier.etablissement)
    end
  end

  def safe_expiration_date(dossier)
    l(dossier.expired_at.to_date, format: :short)
  end

  def annuaire_link(siren_or_siret = nil)
    base_url = "https://annuaire-entreprises.data.gouv.fr"
    return base_url if siren_or_siret.blank?
    "#{base_url}/rechercher?terme=#{siren_or_siret}"
  end

  def france_connect_informations(user_information)
    if user_information.full_name.empty?
      t("shared.dossiers.france_connect_informations.details_no_name")
    else
      t("shared.dossiers.france_connect_informations.details", name: user_information.full_name)
    end
  end

  def pro_connect_informations(user_information)
    if user_information.full_name.empty?
      t("shared.dossiers.pro_connect_informations.details_no_name")
    else
      t("shared.dossiers.pro_connect_informations.details", name: user_information.full_name)
    end
  end

  def clean_string_for_pdf(str)
    str
      &.tr("\r", "\n")
      &.gsub(/&nbsp;/, ' ')
      &.lines&.map { _1.gsub(/[[:space:]]/, ' ').strip }&.join("\n") # replace non breaking space, which are invalid in pdf
  end

  private

  def extract_notification_type(notification_or_type)
    notification_or_type.is_a?(DossierNotification) ? notification_or_type.notification_type : notification_or_type.to_s
  end

  def days_for_specific_badge_notification(notification, type)
    if notification.respond_to?(:display_at) && notification.display_at.present?
      case type
      when DossierNotification.notification_types.fetch(:dossier_depose)
        (Time.current.to_date - (notification.display_at - DossierNotification::DELAY_DOSSIER_DEPOSE).to_date).to_i
      when DossierNotification.notification_types.fetch(:dossier_expirant)
        ((notification.display_at + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks).to_date - Time.current.to_date).to_i
      when DossierNotification.notification_types.fetch(:dossier_suppression)
        ((notification.display_at + Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks).to_date - Time.current.to_date).to_i
      end
    else
      'X'
    end
  end
end
