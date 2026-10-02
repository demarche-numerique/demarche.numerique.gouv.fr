# frozen_string_literal: true

module TabsHelper
  def i18n_tab_from_status(status)
    case status
    when 'a-suivre'
      t('instructeurs.dossiers.labels.to_follow')
    when 'suivis'
      t('instructeurs.dossiers.labels.followed')
    when 'traites'
      t('instructeurs.dossiers.labels.processed')
    when 'tous'
      t('instructeurs.dossiers.labels.total')
    when 'supprimes'
      t('instructeurs.dossiers.labels.trash')
    when 'expirant'
      t('instructeurs.dossiers.labels.close_to_expiration')
    when 'archives'
      t('instructeurs.dossiers.labels.to_archive')
    else
      fail ArgumentError, "Unknown tab status: `#{status}`"
    end
  end

  # Built from the notification_key of the tab, never from its label, which changes with the locale.
  def notification_sticker_id(key)
    "notification-sticker-#{key}"
  end

  def tab_item(label, url, active: false, badge: nil, notification: false, notification_key: nil, small_counter: nil, html_class: nil)
    render partial: 'shared/tab_item', locals: {
      label: label,
      url: url,
      active: active,
      badge: badge,
      notification: notification,
      notification_key: notification_key,
      small_counter: small_counter,
      html_class: html_class,
    }
  end

  def dynamic_tab_item(label, url_or_urls, badge: nil, notification: false, notification_key: nil)
    urls = [url_or_urls].flatten
    url = urls.first
    active = urls.any? { |u| current_page?(u) }

    tab_item(label, url, active: active, badge: badge, notification: notification, notification_key: notification_key)
  end
end
