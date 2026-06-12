import { ApplicationController } from './application_controller';

export class TruncateNotificationsController extends ApplicationController {
  connect() {
    const notificationContainerWidth =
      this.calculateNotificationContainerWidth();

    const notifications = document.querySelectorAll<HTMLElement>(
      '.notification-container-type'
    );
    notifications.forEach((notificationType) => {
      const notificationDossiers = Array.from(
        notificationType.querySelectorAll<HTMLElement>('.notification-dossier')
      );
      const indicator = notificationType.querySelector<HTMLElement>(
        '.notification-indicator'
      );

      let usedWidth = 0;
      let visibleCount = 0;
      let truncateContainer = false;

      for (const notification of notificationDossiers) {
        usedWidth += notification.offsetWidth;
        if (usedWidth < notificationContainerWidth) {
          visibleCount++;
        } else {
          const hiddenCount = notificationDossiers.length - visibleCount;
          truncateContainer = this.truncateNotification(
            truncateContainer,
            hiddenCount,
            indicator!,
            notification
          );
        }
      }
    });
  }

  private calculateNotificationContainerWidth() {
    const notificationBadge = document.querySelector<HTMLElement>(
      '.notification-badge'
    );
    // 1168 : `.notification-container-type` width in desktop view
    return 1168 - notificationBadge!.offsetWidth;
  }

  private truncateNotification(
    truncateContainer: boolean,
    hiddenCount: number,
    indicator: HTMLElement,
    notification: HTMLElement
  ) {
    notification.classList.add('hidden');
    if (truncateContainer == false) {
      if (hiddenCount > 0) {
        indicator!.innerHTML = `<span class="notification-dossier-contenu fr-mr-1w" aria-hidden="true">…</span><span class="notification-dossier-contenu fr-text--bold">(+ ${hiddenCount})</span>`;
      }
    }
    return true;
  }
}
