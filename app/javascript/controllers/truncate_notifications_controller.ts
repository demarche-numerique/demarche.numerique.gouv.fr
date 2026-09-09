import { ApplicationController } from './application_controller';

export class TruncateNotificationsController extends ApplicationController {
  connect() {
    const notificationContainerWidth =
      this.calculateNotificationContainerWidth();

    const notifications = document.querySelectorAll<HTMLElement>(
      '.notification-dossiers'
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
          const hiddenCount = notificationDossiers.length - visibleCount - 1;
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
    const container = document.querySelector<HTMLElement>(
      '.notification-container-type'
    );
    const notificationBadge = document.querySelector<HTMLElement>(
      '.notification-badge'
    );
    return container!.offsetWidth - notificationBadge!.offsetWidth;
  }

  private truncateNotification(
    truncateContainer: boolean,
    hiddenCount: number,
    indicator: HTMLElement,
    notification: HTMLElement
  ) {
    if (truncateContainer == false) {
      if (hiddenCount > 0) {
        indicator!.textContent = `... +${hiddenCount}`;
      }
      notification.style.overflow = 'hidden';
    } else {
      notification.classList.add('hidden');
    }
    return true;
  }
}
