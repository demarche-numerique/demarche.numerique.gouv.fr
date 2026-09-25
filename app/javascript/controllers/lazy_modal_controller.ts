import { ApplicationController } from './application_controller';

interface HTMLTurboFrameElement extends HTMLElement {
  src: string | null;
}

declare const window: Window &
  typeof globalThis & { dsfr?: (el: HTMLElement) => { modal: unknown } };

export default class LazyModalController extends ApplicationController {
  static targets = ['frame'];

  declare readonly frameTarget: HTMLTurboFrameElement;

  load(event: Event): void {
    const button = event.currentTarget as HTMLButtonElement;
    const frame = this.frameTarget;

    const src = button.getAttribute('src');
    if (src) {
      // Une session expirée n'arrive plus jusqu'ici : shared/session-expiry
      // intercepte le 401 en amont. Reste le cas d'une réponse qui ne contient
      // pas le frame attendu — on recharge la page courante plutôt que d'afficher
      // un fragment orphelin.
      frame.addEventListener(
        'turbo:frame-missing',
        (event) => {
          event.preventDefault();
          window.location.reload();
        },
        { once: true }
      );

      frame.src = src;

      frame.addEventListener(
        'turbo:frame-load',
        () => {
          const modalId = button.getAttribute('aria-controls');
          if (modalId) {
            const modal = document.getElementById(modalId);
            if (modal && window.dsfr) {
              // Temporarily remove aria-controls from all OTHER trigger buttons
              // This prevents DSFR from finding the first button instead of the clicked one
              // and giving the focus to the first matching button
              const allButtons = document.querySelectorAll(
                `[aria-controls="${modalId}"]`
              );
              const otherButtonsAriaControls: Array<{
                button: Element;
                value: string;
              }> = [];

              allButtons.forEach((btn) => {
                if (
                  btn !== button &&
                  btn !== modal.querySelector('.fr-btn--close')
                ) {
                  const value = btn.getAttribute('aria-controls');
                  if (value) {
                    otherButtonsAriaControls.push({ button: btn, value });
                    btn.removeAttribute('aria-controls');
                  }
                }
              });

              // @ts-expect-error type not enforced
              window.dsfr(modal).modal.disclose();

              // Restore aria-controls on other buttons after modal is opened
              requestAnimationFrame(() => {
                otherButtonsAriaControls.forEach(({ button, value }) => {
                  button.setAttribute('aria-controls', value);
                });
              });
            }
          }
        },
        { once: true }
      );
    }
  }
}
